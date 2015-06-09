import os
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
def manage_run(command):
    """
    Run a Django management command on the remote server.
    """
    require('environment')
    require('instance', provided_by='instance')
    # Setup the call
    settings = '{0}.settings.{1}'.format(PROJECT_NAME, env.instance)
    manage_sh = u"DJANGO_SETTINGS_MODULE={0} /var/www/{1}/manage.sh ".format(settings,PROJECT_NAME)
    sudo(manage_sh + command, user=PROJECT_NAME)

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
def db_dump(file):
    """
    Dump an instance's database to a remote file.

    Example:

      `fab staging instance:iraq db_dump:/tmp/staging_iraq.dump`

    dumps to staging_iraq.dump
    """
    require('environment', provided_by=SERVER_ENVIRONMENTS)
    require('instance', provided_by='instance')
    remote_file = file

    if files.exists(file):
        if not confirm("Remote file {file} exists and will be overwritten.  Okay?"
                .format(file=remote_file)):
            abort("ERROR: aborting")

    # Don't need remote DB user and password because we're going to run pg_dump as user postgres
    sudo('pg_dump --format=custom --file={outputfile} {dbname}'
         .format(dbname=env.db_name, outputfile=remote_file),
         user='postgres')
    print("Database from {environment} {instance} has been dumped to remote file {file}"
          .format(environment=env.environment, instance=env.instance, file=remote_file))


@task
def db_restore(file):
    """
    Restore a remote DB dump file to a remote instance's database.

    This will rename the existing database to {previous_name}_bak
    and create a completely new database with what's in the dump.

    If there's already a backup database, the restore will fail.

    Example:

      `fab staging instance:iraq db_restore:/tmp/staging_iraq.dump`

    :param file: The remote file to restore.
    """
    require('environment', provided_by=SERVER_ENVIRONMENTS)
    require('instance', provided_by='instance')

    renamed = False
    restored = False

    if not files.exists(file):
        abort("Remote file {file} does not exist".format(file=file))

    try:
        if db_exists(env.db_name):
            # Rename existing DB to backup
            db_backup = '{dbname}_bak'.format(dbname=env.db_name)
            if db_exists(db_backup):
                if confirm("There's already a database named {db_backup}. Replace with new backup?"
                        .format(db_backup=db_backup)):
                    sudo('dropdb {db_backup}'.format(db_backup=db_backup),
                         user='postgres')
                else:
                    abort("ERROR: There's already a database named {db_backup}. "
                          "Restoring would clobber it."
                          .format(db_backup=db_backup))
            sudo('psql -c "ALTER DATABASE {dbname} RENAME TO {db_backup}"'
                 .format(dbname=env.db_name, db_backup=db_backup),
                 user='postgres')
            renamed = True
            print("Renamed {dbname} to {db_backup}".format(dbname=env.db_name, db_backup=db_backup))

        remote_file = file

        # Create new, very empty database.
        # * We can't use --create on the pg_restore because that will always restore to whatever
        #   db name was saved in the dump file, and we don't want to be restricted that way.
        # * Any extensions the backed-up database had will be included in the restore, so we
        #   don't need to enable them now.

        # If these parameters change, also change the parameters in conf/salt/project/db/init.sls
        # (TODO: we could use the output of psql -l to copy most of these settings from the
        # existing database.)
        sudo('createdb --encoding UTF8 --lc-collate=en_US.UTF-8 '
             '--lc-ctype=en_US.UTF-8 --template=template0 --owner {owner} {dbname}'
             .format(dbname=env.db_name, owner=env.db_owner),
             user='postgres')

        # Don't need remote DB user and password because we're going to
        # run pg_restore as user postgres
        sudo('pg_restore --dbname={dbname} {filename}'
             .format(dbname=env.db_name, filename=remote_file),
             user='postgres')
        restored = True

        # Run ANALYZE on the db to help Postgres optimize how it accesses it
        sudo('psql {dbname} -c ANALYZE'.format(dbname=env.db_name),
             user='postgres')

        print("Database for {environment} {instance} has been restored from remote file {file}"
              .format(environment=env.environment, instance=env.instance, file=remote_file))
    finally:
        if renamed and not restored:
            print("Error occurred after renaming current database, trying to rename it back")
            if db_exists(env.db_name):
                # We already created the new db, but restore failed; delete it
                sudo('dropdb {dbname}'.format(dbname=env.dbname), user='postgres')
            sudo('psql -c "ALTER DATABASE {db_backup} RENAME TO {dbname}"'
                 .format(dbname=env.db_name, db_backup=db_backup),
                 user='postgres')
            print("Successfully put back the original database.")
