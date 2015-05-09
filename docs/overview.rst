Overview
========

This is an overview of how CTS v3 is deployed.

Servers and environments
------------------------

Deploys are done to a single server, which will serve all
the CTS instances under one domain name using URL prefixing.

For development and test purposes, CTS v3 can be deployed to
servers other than production. These are called "environments",
and there are three defined initially:

* vagrant
* staging
* production

The `fab` commands used to deploy and provision a server always
take an environment name as the first argument, e.g.
``fab staging do_something``.

When deploying to a server, the code is deployed from a branch
of the code repository on github. Which branch is used is controlled by
a setting in the local file ``conf/pillar/<ENVIRONMENT>/env.sls``,
e.g. ``conf/pillar/staging/env.sls`` might contain::

    environment: staging

    domain: cts-staging.caktusgroup.com

    repo:
      url: git@github.com:theirc/CTS.git
      branch: origin/develop

This indicates that the staging server will use the code
from the ``origin/develop`` branch.

Instances
---------

On a server, there can be multiple copies of CTS running, each with
completely independent data. Each copy is called an `instance`.

All the instances on a server are running the same code, but they
run in different processes and use different databases.

An nginx server receives incoming requests and routes them to the
appropriate instance based on the first part of the URL path.  E.g.
``https://cts.rescue.org/IQ/`` might go to an instance for Iraq, while
``https://cts.rescue.org/TR/`` might go to an instance for Turkey.

The instances are defined in the file ``conf/pillar/project.sls`` and
are the same for all environments.  Here's a sample excerpt from that
file::

    instances:
      turkey:
        name: Turkey
        prefix: /TR
        currency: TRY
        port: 8001
      iraq:
        name: Iraq
        prefix: /IQ
        currency: IQD
        port: 8002
      jordan:
        name: Jordan
        prefix: /JO
        currency: JOD
        port: 8003

Note that this file defines for each instance
a human-readable name, a URL prefix, the international
code for the instance's currency, and an internal port where the instance will listen.

Logs for each instance are in ``/var/www/cts/log/<INSTANCE>/`` on the server,
where ``<INSTANCE>`` is the key of the instance in the configuration, e.g. ``iraq``
or ``turkey``.

Some fab commands require an instance to be specified. Here's an example of how
that is done::

    fab staging instance:iraq manage_shell

For each instance, there's a file ``cts/settings/<INSTANCE>.py`` with the settings
that are unique for that instance. See the existing files, such as ``cts/settings/jordan.py``,
to see what needs to be in the instance's settings file.  (Actually, very little
needs to be in there.)

The software
------------

CTS is deployed on the following stack.

- OS: Ubuntu 12.04 LTS
- Python: 2.7
- Database: Postgres 9.1
- Application Server: Gunicorn
- Frontend Server: Nginx
- Cache: Memcached


In development
---------------

When running locally (e.g. ``django-admin.py runserver``), the environment name
is ``dev`` and there's only one instance, ``local``, with no URL prefix. Since there's
no prefix, it should work the way developers are used to.
