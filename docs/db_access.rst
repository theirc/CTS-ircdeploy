Production Databases
====================


Read-only Database Access
-------------------------

You can arrange for a readonly user to have access to an instance's database
by editing the secrets file, deploying, and adjusting the AWS security group
rules to allow incoming connections from wherever the readonly user is going
to connect from.


Copying data from a server to your local environment
----------------------------------------------------

Here are the steps to create a new local database and load it with the
data from one of the server instances.  This will dump the server instance's
database to a binary dump file, download it, create a new local database
that's completely empty and has the right settings, and load the
server's data into it::

    SERVER=staging
    INSTANCE=turkey
    DB_NAME=ctsdb
    fab ${SERVER} instance:${INSTANCE} db_dump:${SERVER}_${INSTANCE}.dump
    createdb --encoding UTF8 --lc-collate=en_US.UTF-8 --lc-ctype=en_US.UTF-8 --template=template0 ${DB_NAME}
    pg_restore --dbname=${DB_NAME} --no-owner ${SERVER}_${INSTANCE}.dump

(Note that, unlike creating a database to start from scratch, in this
case the database should be created from the `template0` template,
not the template that has the extensions. The extensions are dumped
and restored just like the rest of the database contents, so they need
not to be in the database we're restoring into.)
