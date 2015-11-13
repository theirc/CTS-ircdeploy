Backups
=======

How backups are performed
-------------------------

The databases are hosted on AWS RDS and backups are run there.

How to check that backups are working
-------------------------------------

Use the AWS Console and check the RDS instance's backups.  (TBD: where
to look for that in the console.)

How to recover in the event of a lost server
--------------------------------------------

* Restore the desired RDS backup - this will create a new RDS instance containing
  the databases as of the last backup
* Dump the CTS databases from the new RDS instance
* Restore the CTS databases from those dumps to the live RDS instance

    $ fab production instance:[iraq|turkey|jordan] db_restore:/tmp/db.backup

* Now you can remove the RDS instance that was created when restoring the backup
