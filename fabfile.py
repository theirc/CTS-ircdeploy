import os
from pprint import pprint
import re
import tempfile
from fabric.context_managers import cd
from fabric.contrib.files import exists

import yaml

from fabric.api import env, execute, get, hide, lcd, local, put, require, run, settings, sudo, task
from fabric.colors import red
from fabric.contrib import files, project
from fabric.contrib.console import confirm
from fabric.utils import abort

PROJECT_ROOT = os.path.dirname(__file__)
CONF_ROOT = os.path.join(PROJECT_ROOT, 'conf')

MARGARITA_DIR = '/var/lib/margarita'

PROJECT_NAME = 'cts'

project_sls_file = os.path.join(CONF_ROOT, 'pillar', 'project.sls')
projects = yaml.safe_load(open(project_sls_file, 'r'))


SERVER_ENVIRONMENTS = ['staging', 'production', 'testing']
INSTANCES = projects['instances'].keys()  # e.g. 'iraq', 'turkey'


@task
def staging():
    env.environment = 'staging'
    # This hostname for our own use to connect to the server to manage it.
    # To change the public domain, see conf/pillar/<envname>/env.sls
    env.hosts = ['ec2-54-86-123-211.compute-1.amazonaws.com']


@task
def production():
    env.environment = 'production'
    # This hostname for our own use to connect to the server to manage it.
    # To change the public domain, see conf/pillar/<envname>/env.sls
    env.hosts = ['ec2-54-77-174-184.eu-west-1.compute.amazonaws.com']


@task
def instance(name):
    # Set an instance. Only required for some commands
    if name not in INSTANCES:
        abort("%s is not a valid instance; instances are %s" % (name, INSTANCES))
    env.instance = name
    # If these lines change, change conf/salt/project/db/init_sls
    # and cts/settings/staging.py.
    env.db_name = 'cts_%s' % env.instance
    env.db_owner = 'cts_%s' % env.instance
    env.settings = '{0}.settings.{1}'.format(PROJECT_NAME, env.instance)


@task
def ssh():
    require('hosts')
    local('ssh %s' % env.hosts[0])


@task
def sync():
    """Rysnc local states and pillar data to the master."""
    # Check for missing local secrets so that they don't get deleted
    # project.rsync_project fails if host is not set
    margarita()
    if not have_secrets():
        get_secrets()
    else:
        # Check for differences in the secrets file
        remote_file = os.path.join('/srv/pillar/', env.environment, 'secrets.sls')
        with lcd(os.path.join(CONF_ROOT, 'pillar',env. environment)):
            if files.exists(remote_file):
                get(remote_file, 'secrets.sls.remote')
            else:
                local('touch secrets.sls.remote')
            with settings(warn_only=True):
                result = local('diff -u secrets.sls.remote secrets.sls')
                if result.failed and not confirm(red("Above changes will be made to %s/secrets.sls. Continue?" % (env.environment, ))):
                    abort("Aborted. File have been copied to secrets.sls.remote. " +
                      "Resolve conflicts, then retry.")
                else:
                    local("rm secrets.sls.remote")
        salt_root = CONF_ROOT if CONF_ROOT.endswith('/') else CONF_ROOT + '/'
        project.rsync_project(local_dir=salt_root, remote_dir='/tmp/salt', delete=True)
        sudo('rm -rf /srv/salt /srv/pillar')
        sudo('mv /tmp/salt/salt /srv/')
        sudo('mv /tmp/salt/pillar /srv/')
        sudo('rmdir /tmp/salt/')


def have_secrets():
    """Check if the local secret file exists for the environment."""
    local_file = os.path.join(CONF_ROOT, 'pillar', env.environment, 'secrets.sls')
    return os.path.exists(local_file)


@task
def get_secrets():
    """Grab the latest secrets file"""
    local_file = os.path.join(CONF_ROOT, 'pillar', env.environment, 'secrets.sls')
    if os.path.exists(local_file):
        local('cp {0} {0}.bak'.format(local_file))
    remote_file = os.path.join('/srv/pillar/', env.environment, 'secrets.sls')
    get(remote_file, local_file)


def margarita():
    if exists(os.path.join(MARGARITA_DIR, '.git')):
        with cd(MARGARITA_DIR):
            sudo('git fetch && git checkout origin/master')
    else:
        sudo('git clone git://github.com/caktus/margarita.git {0}'.format(MARGARITA_DIR))


@task
def setup_minion():
    """Set up a minion"""
    require('environment')
    # This could be the first time we try to use git on a new system
    if not exists('/usr/bin/git'):
        sudo('apt-get install git -qq -y')
    margarita()
    # install salt minion if it's not there already
    with settings(warn_only=True):
        with hide('running', 'stdout', 'stderr'):
            installed = run('which salt-call')
    if not installed:
        # install salt-minion from PPA
        sudo('apt-get update -qq -y')
        sudo('apt-get install python-software-properties -qq -y')
        sudo('add-apt-repository ppa:saltstack/salt -y')
        sudo('apt-get update -qq')
        sudo('apt-get install salt-minion -qq -y')
    config = {
        'output': 'mixed',
        'file_client': 'local',
        'file_roots': {
            'base': [
                MARGARITA_DIR,
                '/srv/salt',
            ],
        },
        'grains': {
            'environment': env.environment,
        },
        'mine_functions': {
            'network.interfaces': []
        },
        'id': env.host,
        # Time in seconds that a command can take before the minion will put the job
        # in the background and return. Default is 5 seconds, which seems ridiculous.
        'timeout': 3000,
    }
    _, path = tempfile.mkstemp()
    with open(path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    put(local_path=path, remote_path="/etc/salt/minion", use_sudo=True)
    sudo('service salt-minion restart')


@task
def salt(cmd):
    """Run arbitrary salt commands."""
    print("Detailed output will be on the remote system in /tmp/salt.out.")
    sudo("LC_ALL=en_US.UTF-8 salt-call --local --log-level=error --out-file=/tmp/salt.out {0}".format(cmd))
    # sudo("LC_ALL=en_US.UTF-8 salt-call --local --log-level=error {0}".format(cmd))


@task
def highstate():
    """Run highstate"""
    print("This can take a long time without output, be patient")
    salt('state.highstate')


@task
def deploy():
    """Deploy to a given environment by pushing the latest states and executing the highstate."""
    require('environment')
    sync()
    salt('saltutil.sync_all')
    highstate()

@task
def justdeploy():
    """Just pull the latest code from github; NOTHING else."""
    require('environment')
    salt('state.sls project.repo')


@task
def printenv():
    """Print the env in which we run Django processes"""
    pprint(getenv())


def getenv():
    """Return a dictionary containing the environment variables that will
    be set when we run Django processes on the server"""
    require('environment')
    require('instance', provided_by='instance')
    command = u"DJANGO_SETTINGS_MODULE={0} " \
              u"/var/www/{1}/run.sh printenv".format(env.settings, PROJECT_NAME)
    out = sudo(command, user=PROJECT_NAME)
    dictionary = dict([line.split('=', 1) for line in out.splitlines()])
    # Remove some artifacts of our logging into the server and running printenv using sudo
    for name in ['TERM', 'SHLVL', 'LESS', 'SUDO_USER', 'SUDO_UID', 'SUDO_COMMAND', 'SUDO_GID',
                 'MAIL', '_', 'PS1']:
        if name in dictionary:
            del dictionary[name]
    return dictionary


@task
def manage_run(command):
    """
    Run a Django management command on the remote server.
    """
    require('environment')
    require('instance', provided_by='instance')
    # Setup the call
    manage_sh = u"DJANGO_SETTINGS_MODULE={0} /var/www/{1}/manage.sh ".format(env.settings, PROJECT_NAME)
    return sudo(manage_sh + command, user=PROJECT_NAME)

@task
def manage_shell():
    manage_run('shell')


@task
def collectstatic():
    manage_run('collectstatic --noinput')


@task
def db_backup():
    """
    Backup the database to S3 just like the nightly cron job
    """
    require('environment')
    require('instance', provided_by='instance')
    manage_run("dbbackup --encrypt")


def db_exists(dbname):
    """
    Return True if a db named DBNAME exists on the remote host.
    """
    require('environment', provided_by=SERVER_ENVIRONMENTS)
    output = sudo('psql -l --pset=format=unaligned', user='postgres')
    dbnames = [line.split('|')[0] for line in output.splitlines()]
    return dbname in dbnames


@task
def print_dsn():
    pprint(get_dsn())


def get_dsn():
    """
    Return the database settings for the currently selected environment
    in DSN syntax. That's a single string with space-separated settings, e.g.

        dbname='foo' host='example.com' port='1234'

    etc etc.
    """
    require('environment', provided_by=SERVER_ENVIRONMENTS)
    require('instance', provided_by='instance')

    if not hasattr(env, 'dsn'):
        # Get DSN by running sqldsn on the server with the current settings.
        # If host='' on the server, change it to the remote hostname so we
        # can access it from here.  Also fill in the default port.
        env.dsn = manage_run('sqldsn --quiet')\
            .replace("host=''", "host='{HOST}'".format(HOST=env.hosts[0]))\
            .replace("port=''", "port='5432'")
    return env.dsn


def get_parm_from_dsn(dsn, parm):
    """
    Given a DSN (see ``get_dsn``) and the name of one of the parameters
    from it, return the value of that parameter. If that parameter is not
    found, fails hard.
    """
    regex = re.compile(parm + r"='([^']*)'")
    m = regex.search(dsn)
    if not m:
        abort("No match for %s in %s" % (regex.pattern, dsn))
    return regex.search(dsn).group(1)


def get_dbname_from_dsn():
    """
    Return the DBNAME from the server instance's DSN
    """
    return get_parm_from_dsn(get_dsn(), 'dbname')


def get_dsn_for_database(dbname):
    """
    Return the DSN tweaked to connect to the named database.
    :param dbname:
    :return:
    """
    return get_dsn().replace("dbname='%s'" % get_dbname_from_dsn(),
                             "dbname='%s'" % dbname)


# It's not documented, but at least some Postgres commmands let you give the DSN as
# the value of the "--dbname" option.


@task
def dump_to_local(file):
    """
    Dump an instance's database to a local file.
    :param file:
    :return:
    """
    require('environment', provided_by=SERVER_ENVIRONMENTS)
    require('instance', provided_by='instance')
    local_file = file

    dsn = get_dsn()
    local('pg_dump --format=custom --file={local_file} "{DSN}"'.format(local_file=local_file, DSN=dsn))


@task
def restore_from_local(file, new_dbname):
    """
    Restore a local postgres dump file to an instance's database.

    The database should have been created already, and the database
    user in the Django settings should have access to it.

    Also, any extensions must ALREADY have been created in the
    database, because only superusers can create extensions in a database
    and typically the user we've configured on the Django server is not
    a superuser.

    And, the ownership of the extensions must be the same as the
    database owner...
    """
    require('environment', provided_by=SERVER_ENVIRONMENTS)
    require('instance', provided_by='instance')
    local_file = file
    # Restore to it
    dsn_for_new_db = get_dsn_for_database(new_dbname)
    os.environ['PGPASSWORD'] = get_parm_from_dsn(dsn_for_new_db, 'password')
    local('pg_restore'
          ' --no-owner'
          ' --no-acl'
          ' --dbname="{DSN}"'
          ' {filename}'.format(
        DSN=dsn_for_new_db,
        filename=local_file),
    )

