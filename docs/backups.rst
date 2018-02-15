CTS backups
===========

Backups are taken regularly and stored on the Caktus backup server. This document explains how to
access and use those backups.

Getting a backup dump and restoring it locally
----------------------------------------------

Steps you can do ahead of time:

* Get access to the Caktus backup server (open a tech support request).

When you need to restore a backup:

* Make sure you are in your CTS-IRCDeploy directory, and not in the CTS project directory::

    $ git config --get remote.origin.url
    git@github.com:theirc/CTS-ircdeploy.git

* List the files in the latest backup directory and find the most recent backup file for each
  instance (i.e. "iraq", "jordan", and "turkey")::

    $ backup_path=/mnt/rsnapshot/cts/daily.0/home/caktus-backup
    $ ssh caktus-backup@backup.caktus.lan ls $backup_path/cts_iraq* | tail -1
    cts_iraq.rescue.org-20170927.bz2
    $ ssh caktus-backup@backup.caktus.lan ls $backup_path/cts_jordan* | tail -1
    cts_jordan.rescue.org-20170927.bz2
    $ ssh caktus-backup@backup.caktus.lan ls $backup_path/cts_turkey* | tail -1
    cts_turkey.rescue.org-20170927.bz2

* Copy those files your local directory::

    $ scp caktus-backup@backup.caktus.lan:${backup_path}/cts_iraq.rescue.org-20170927.bz2 cts_iraq.bz2
    $ scp caktus-backup@backup.caktus.lan:${backup_path}/cts_jordan.rescue.org-20170927.bz2 cts_jordan.bz2
    $ scp caktus-backup@backup.caktus.lan:${backup_path}/cts_turkey.rescue.org-20170927.bz2 cts_turkey.bz2

  The iraq file is about 3MB, and the others are about 5MB each, as of Sept 2017.

* Decompress the file using the `-k` flag which keeps the compressed version around (since we'll be
  SCP'ing that to staging in a few steps)::

    $ bunzip2 -k cts_iraq.bz2
    $ bunzip2 -k cts_jordan.bz2
    $ bunzip2 -k cts_turkey.bz2

* Drop your existing local database and restore from the backup::

    $ dropdb cts
    $ createdb --template=template0 cts
    $ psql --quiet cts -f cts_iraq > sql-import.log 2>&1

  You can look through `sql-import.log` to view the output from that command. There will be a bunch
  of errors about missing relations and roles. It's OK to ignore them.

* Change to the CTS project directory::

    $ cd ../CTS
    $ git config --get remote.origin.url
    git@github.com:theirc/CTS.git

* Migrate the database::

    $ workon cts
    $ python manage.py migrate --noinput
    $ python manage.py createsuperuser
    $ python manage.py runserver

  Check out localhost:8000 and poke around.

* Repeat the above process with the 'jordan' and 'turkey' dumps.


Bringing up a new site using the backup dump
--------------------------------------------

* Change back to the CTS project directory::

    $ cd ../CTS-ircdeploy
    $ git config --get remote.origin.url
    git@github.com:theirc/CTS-ircdeploy.git

* Copy the three compressed dump files to staging::

    $ fab staging put_file:cts_iraq.bz2
    $ fab staging put_file:cts_jordan.bz2
    $ fab staging put_file:cts_turkey.bz2

* SSH into staging and unzip the files::

    $ fab staging ssh
    user@cts-staging$ cd /tmp
    user@cts-staging$ bunzip2 cts_iraq.bz2
    user@cts-staging$ bunzip2 cts_jordan.bz2
    user@cts-staging$ bunzip2 cts_turkey.bz2

* Stop the web and celery processes::

    user@cts-staging$ sudo supervisorctl stop all

* Switch to the ``cts`` user and set up the environment to allow you to access RDS::

    user@cts-staging$ sudo -u cts -i
    cts@cts-staging$ . /var/www/cts/run.sh
    (env)cts@cts-staging$ export PGHOST=$DB_HOST PGPASSWORD=$DB_PASSWORD PGUSER=$DB_USER
    (env)cts@cts-staging$ dropdb cts_iraq
    (env)cts@cts-staging$ createdb cts_iraq
    (env)cts@cts-staging$ psql --quiet cts_iraq -f /tmp/cts_iraq > /tmp/sql-import.log 2>&1

* Review the sql-import.log. There will be lots of errors about missing roles, tables, etc, but that
  is OK. Now, run migrations::

    (env)cts@cts-staging$ INSTANCE=iraq django-admin.py migrate --noinput

* Repeat this process for the other 2 instances: 'jordan', and 'turkey'.

* After completing all 3 instances, switch back to your user and restart the servers::

    (env)cts@cts-staging$ logout
    user@cts-staging$ sudo supervisorctl start all
    cts-celery-jordan: started
    cts-turkey-server: started
    cts-celery-turkey: started
    cts-celery-beat-jordan: started
    cts-celery-iraq: started
    cts-celery-beat-iraq: started
    cts-jordan-server: started
    cts-iraq-server: started
    cts-celery-beat-turkey: started

* Give the load balancer a few minutes to realize we’re healthy, then poke around the staging
  servers to make sure everything looks good.

* Finally clean up the dumps from the staging server and locally::

    user@cts-staging$ cd /tmp/
    user@cts-staging$ sudo rm -f cts_* sql-import.log
    user@cts-staging$ logout
    Connection to ec2-54-86-123-211.compute-1.amazonaws.com closed.

    Done.
    $ rm -f cts_* sql-import.log
