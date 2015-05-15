Common Administration Tasks
===========================

Here are some common tasks and how to perform them.

Get secrets
-----------

Since the secrets aren't stored in Git, it's a good idea, before doing any
server administration, to fetch the current secrets from the servers::

  fab staging get_secrets
  fab production get_secrets

Update secrets
--------------

If you need to update any secrets, be sure to first get the latest secrets
file from the relevant server (see above). Then you can edit your local copy
(e.g. `conf/pillar/production/secrets.sls` or `conf/pillar/staging/secrets.sls`)
and deploy (see next item).

Deploy new code
---------------

Running a deploy does several things:

#. If the local secrets files are different from the ones on the server,
   display the differences and ask whether to update the server files
   from the local ones. If you answer "no" at this point, the deploy is
   aborted.

#. Ensure system and Python packages are installed, configuration files are
   correct, and generally check and update the provisioning on the server.
   This uses `Salt <https://salt.readthedocs.org/en/latest/>`_.

#. Sync all the configuration files under `conf` from your local system
   to the server. This makes it easier to test deploy changes without having
   to continually commit possibly broken code first.

#. Checkout the source code from github. It'll use whatever branch name is
   set in the local `conf/pillar/<environment>/env.sls` file, so you can test
   by editing that file locally and deploying.  But the actual source code
   you want to test has to be pushed to github.  (By "source code" here, we
   basically mean everything in the git repository that is
   outside of the `conf` directory.)

#. Run the usual Django deploy-time commmands such as `collectstatic` and
   `syncdb --migrate`.

#. Restart the servers

To do a deploy, the command is just "deploy", e.g.::

  fab production deploy



Run arbitrary Django management commands
----------------------------------------

If you want to run an arbitrary Django management command, like "syncdb"
or "dbshell", you can use a command from your local system like::

  fab staging instance:iraq manage_run:syncdb

Note that you have to pick an instance.


SSH to the server
-----------------

There's a shortcut for this::

  fab staging ssh
