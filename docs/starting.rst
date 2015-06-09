Getting Started
===============

This is a step-by-step guide to start administering IRC's CTS servers.

#. Clone the git repository::

    git clone https://github.com/theirc/CTS-ircdeploy.git
    cd CTS-ircdeploy/

Or if you'll be contributing to the repository::

    git clone git@github.com:theirc/CTS-ircdeploy.git
    cd CTS-ircdeploy/

#. To setup your local environment you should create a virtualenv and install the necessary requirements::

     mkvirtualenv cts-ircdeploy
     $VIRTUAL_ENV/bin/pip install -r $PWD/requirements.txt

#. Add a developer user to the configuration.

   Edit ``conf/pillar/devs.sls`` and add a username and SSH public key. This will be used
   to grant access to the servers later.

   Each user record should match the format::

    <username>:
      public_key:
       - ssh-rsa <Full SSH Public Key would go here>

   e.g.

    popeye:
      public_key:
       - ssh-rsa AAAAB...XXXX popeye@example.com

   Additional developers can be added later, but you will need to create at least one user for
   yourself.

   Submit a pull request to the repository and get the change merged.

#. Ask someone who already has access to the server to deploy.

   This will apply your changes, so you'll have an account on the server with ssh
   access and sudo privileges.

   If you need to administer multiple environments, ask to have the changes deployed
   to all of them.

#. Fetch the latest secrets.

   The secrets files are not in git, so you'll need to download them from the server.
   Each environment has its own secrets file, so you'll need to run the appropriate
   command for each. Suppose you're working with the staging server, then you'd run::

     fab staging get_secrets

   After running this, you should have a local file `conf/pillar/staging/secrets.sls`
   with the passwords, keys, etc that aren't kept in git.

At this point, you should be able to do any of the needed :doc:`administration tasks <tasks>`.
