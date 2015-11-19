Provisioning Servers and Environments
=====================================


New EC2 Servers
---------------

These are instructions for creating and deploying a new server.
Production servers are typically deployed on Amazon EC2 servers,
but most of these instructions would apply to any server.

For the purposes of this documentation, we'll assume we're adding
a new server, to be referred to as the ``testing`` environment.

#. Create a new EC2 server. Some tips:

 * Put it in a region close to where most users will be, e.g. Ireland (eu-west-1).
   (To switch regions in the AWS EC2 console, look near the top-right of the window for
   a light-gray selector on a black background.)
 * Use an AMI (image) of Ubuntu 12.04 server, 64-bit, EBS - e.g. ubuntu-precise-12.04-amd64-server-20140408 (ami-d1f308a6)
 * Be sure to save the private key that is created, or use
   an existing one you already own. (Caktus: key pairs are stored
   in LastPass, search for CTS.) The AWS private key is only
   needed until CTS has been deployed the first time, but it
   is essential until then.

#. If needed, follow the `New Environments`_ to add a new environment.

#. Add the new server's ssh key to your ssh-agent, e.g.::

    ssh-add /path/to/newserver.pem

   This will allow you to ssh into the new server as root initially.
   After we've finished our deploy, you'll have your own userid on
   the server that you can use to ssh in.

#. Create a minion::

    fab -u root testing setup_minion

#. Initial deploy::

    fab -u root testing deploy

After that, developer accounts will exist on the server with ssh access,
so "-u root" will no longer be needed.  You'll be able to update
the server with::

  fab testing deploy


New Environments
----------------

(You should rarely need to do this.)

An environment defines a server where CTS will run, e.g. "production"
or "staging".

Creating a new environment requires adding parts of its configuration
to multiple places in the CTS configuration files.

For the purposes of this documentation, we'll assume we're adding
a new environment named ``testing``, which will be accessed
at ``cts-testing.caktusgroup.com``.

#. Edit the fabfile (``fabfile.py`` in the top directory).
   Create a new task near the top, modeled
   on the existing tasks like 'production'.  Fill in
   the new server's hostname or IP address.  Like this::

        @task
        def testing():
            env.environment = 'testing'
            env.hosts = ['cts-testing.caktusgroup.com']
            env.master = env.hosts[0]

#. In the fabfile, add the new environment to ``SERVER_ENVIRONMENTS`` near the top::

    SERVER_ENVIRONMENTS = ['staging', 'production', 'testing']

#. In ``conf/pillar/top.sls``, add the new environment to the list::

        {% for env in ['staging', 'production', 'testing'] %}

#. Under the ``conf/pillar`` directory, create a new directory
   with the same name as your new environment.  Copy the ``env.sls`` and
   ``secrets.sls`` files from an existing directory, such as ``production``.
   Add the ``env.sls`` file to git, but DO NOT add the ``secrets.sls`` file to git.
   Edit both as seems appropriate.  The environment and domain names
   should match those in ``fabfile.py``.

   conf/pillar/testing/env.sls::

        environment: testing

        domain: cts-testing.caktusgroup.com

        repo:
          url: git@github.com:theirc/CTS.git
          branch: origin/develop

        # Additional public environment variables to set for the project
        env:
          FOO: BAR

   The repo will also need a deployment key generated so that the Salt minion can access the
   repository. Or if the repository already has a deployment key, you'll need access to
   the private key. See the
   `Github docs on managing deploy keys <https://help.github.com/articles/managing-deploy-keys>`_

   The private key should be added to ``conf/pillar/<environment>/secrets.sls`` under the
   label ``github_deploy_key``::

    github_deploy_key: |
      -----BEGIN RSA PRIVATE KEY-----
      foobar
      -----END RSA PRIVATE KEY-----

   You may choose to include the public SSH key in the repo as well, but this is not strictly required.

   The ``project_name`` and ``python_version`` are set in ``conf/pillar/project.sls``.
   Currently we support using Python 2.7 on this project.


   The ``secrets.sls`` can also contain a section to enable HTTP basic authentication. This
   is useful for staging environments where you want to limit who can see the site before it
   is ready. This will also prevent bots from crawling and indexing the pages. To enable basic
   auth simply add a section called ``http_auth`` in the
   relevant ``conf/pillar/<environment>/secrets.sls``::

        http_auth:
          admin: 123456

   This should be a list of key/value pairs. The keys will serve as the usernames and
   the values will be the password. As with all password usage please pick a strong
   password.

   Here's what ``conf/pillar/testing/secrets.sls`` might look like::

        secrets:
            DB_PASSWORD: xxxxxx
            BROKER_PASSWORD: yyyyy
            newrelic_license_key: zzzzz

            # Iraq:
            ONA_DOMAIN_IQ: ona-staging.caktusgroup.com
            ONA_API_ACCESS_TOKEN_IQ: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
            ONA_PACKAGE_FORM_IDS_IQ: 4
            ONA_DEVICEID_VERIFICATION_FORM_ID_IQ: 52

            # Jordan:
            ONA_DOMAIN_JO: ona-staging.caktusgroup.com
            ONA_API_ACCESS_TOKEN_JO: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
            ONA_PACKAGE_FORM_IDS_JO: 3;14
            ONA_DEVICEID_VERIFICATION_FORM_ID_JO: 35

            # Turkey:
            ONA_DOMAIN_TR: ona-staging.caktusgroup.com
            ONA_API_ACCESS_TOKEN_TR: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
            ONA_PACKAGE_FORM_IDS_TR: 5;6;23
            ONA_DEVICEID_VERIFICATION_FORM_ID_TR: 65

        # Uncomment and update username/password to enable HTTP basic auth
        # Comment out to enable access to the public to the site
        http_auth:
            caktus: abc123

        github_deploy_key: |
            -----BEGIN RSA PRIVATE KEY-----
            xxxxxxxx....xxxxxxxxx
            -----END RSA PRIVATE KEY-----

        # Key and cert are optional; if either is missing, self-signed cert will be generated
        ssl_certificate: |
            -----BEGIN CERTIFICATE-----
            MIIFtzCCBJ+gAwIBAgIRAKExk5E8hLbFJa3HRZCMlowwDQYJKoZIhvcNAQEFBQAw
            ...
            lgFKqqiPJXgcYrkEaCFpGG2KVI2oRVCc6EOS
            -----END CERTIFICATE-----

        ssl_key: |
            -----BEGIN PRIVATE KEY-----
            MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCoU2/FjOX/XWbf
            ...
            VtAT+BRfNZvJ3f2bWV8U2A==
            -----END PRIVATE KEY-----

#. Edit ``conf/salt/project/new_relic_webmon/newrelic.ini``.  At the end, add a new New Relic environment::

        [newrelic:testing]
        monitor_mode = false

#. Commit changes to git and push them. Merge to master if this
   is going to be a production server, or to whatever branch ``env.sls`` is
   configured to pull from.

   If you want to test without merging the changes to master yet, then
   push the changes to some other branch, and edit your local copy of
   ``conf/pillar/testing/env.sls`` to change the branch name to the one
   you're using.
