Backups
=======

How backups are performed
-------------------------

The `Django dbbackup <http://django-dbbackup.readthedocs.org/en/latest/>`_
package is installed.  This adds management commands for backing up and
restoring databases and media.

On each server, we set up a cron job for each instance that looks something like::

    {{minute}} 0 * * *    {{ project_name }} /var/www/{{ project_name }}/manage.sh dbbackup --encrypt --settings=cts.settings.{{ instance }}

where ``{{minute}}`` varies depending on the instance so all the backups aren't
running at the same time.

(Note that this backups up the database, but not the media. The CTS site
does not have any media to back up, so we skip running the command.)

Configuration is done via the secrets file, e.g.::

    secrets:
        # ...
        DBBACKUP_S3_BUCKET: 'bucket-name'
        DBBACKUP_S3_ACCESS_KEY: 'AWS access-key'
        DBBACKUP_S3_SECRET_KEY: 'AWS secret-key'
        DBBACKUP_GPG_RECIPIENT: 'GPG user id (short hex string)'
        DBBACKUP_GPG_ALWAYS_TRUST: 'True'

Backup files are written to the specified S3 bucket, in a directory
named `{{ environment }}/{{ instance }}`, e.g. ``production/jordan``.

When backups are run
--------------------

#. Per the cron jobs, see above, once each day.

Running a backup manually
-------------------------

You can use ``fab db_backup``, e.g.::

    $ fab staging instance:jordan db_backup

These will run backups on the server just as if they had been run from
cron, so the backups will be named and written to S3 just the same.

How to check that backups are working
-------------------------------------

* Check the secrets file on the server to see what S3 bucket the backups should
  be going to
* Log into the AWS console and look at that bucket
* Make sure new backups have been written daily for
  each server and instance.

* Download a database backup
* The top lines of the file should be::

    -----BEGIN PGP MESSAGE-----
    Version: GnuPG v1.4.11 (GNU/Linux)

* Get access to the GPG keypair used for the backups.  Add the keypair to
  your GPG keypair.

* Decrypt the file::

    gpg2 2014-12-01-1215-default.backup

  It'll prompt for a new filename. I'll assume you use ``db.backup``.

* See if the db.backup file looks like a Postgres backup::

    $ file db.backup
    db.backup: PostgreSQL custom database dump - v1.12-0


How to recover in the event of a lost server
--------------------------------------------

* Download the latest backup file for an instance
* Decrypt it
* Upload it::

    $ scp db.backup cts.rescue.org:/tmp/db.backup

* Restore the Postgres database backup::

    $ fab production instance:[iraq|turkey|jordan] db_restore:/tmp/db.backup

* Repeat for each instance
