Server Setup Reference
======================

This is a detailed description of how a server ends up
configured by the CTS provisioning process.


Files
-----

Below is the server layout created by this provisioning process::

    /var/www/cts/
        source/
        env/
        log/
        public/
            static/
            media/
        ssl/

``source`` contains the source code of the project, checked out from git. ``env``
is the `virtualenv <http://www.virtualenv.org/>`_ for Python requirements. ``log``
stores the Nginx, Gunicorn and other logs used by the project. ``public``
holds the static resources (css/js) for the project and the uploaded user media.
``public/static/`` and ``public/media/`` map to the ``STATIC_ROOT`` and
``MEDIA_ROOT`` settings. ``ssl`` contains the SSL key and certificate pair.

Configuration files are updated in::

    /etc/nginx
    /etc/postgresql
    /etc/rabbitmq
    /etc/supervisor


Processes
---------


Nginx
~~~~~~

Incoming HTTP requests are received by the Nginx web server.
``/etc/nginx/sites-enabled/cts.conf`` has the specific configuration
for CTS.

Nginx serves static files itself, and routes dynamic requests to
the appropriate backend processes.  It uses the request URL path
to determine how to handle each request.

Nginx is started by an init.d script. There is only one
logical nginx running on a server, though it might consist
of a master process and multiple worker processes.


Gunicorn
~~~~~~~~

Gunicorn is a Python WSGI server. It is used to run processes
with the Django code that can handle HTTP requests routed from
Nginx.

Gunicorn processes are managed by Supervisord.

For each CTS instance, there will be one or more Gunicorn
processes running on the server.


Celery
~~~~~~

Celery is a Python library allowing tasks to be scheduled for later
execution. In CTS, Celery tasks are used to poll for new package
scans.

There are two kinds of celery processes.  Worker processes do the
work. There can be many worker processes for an instance. A beat
process is like `cron`: it schedules tasks at certain times. An
instance only has one beat process.

Celery processes are managed by Supervisord.


Supervisor
~~~~~~~~~~

Supervisor is a daemon that manages background processes.
Each process is configured by a file in /etc/supervisor/conf.d,
and supervisor ensures that each process is started and
continues to run.

CTS uses Supervisor to manage long-running Python processes,
like Gunicorn and Celery.

Supervisor itself is started by an init.d script.

Only one logical Supervisor process runs on a server.


Rabbit MQ
~~~~~~~~~

Rabbit MQ provides reliable asynchronous message queuing among
Celery's processes.

Rabbit MQ is started by an init.d script.

Only one logical Rabbit MQ runs on a server.


Postgres
~~~~~~~~

Postgres is our primary database server.

Postgres is started by an init.d script.

Only one logical Postgres server runs on a server.
