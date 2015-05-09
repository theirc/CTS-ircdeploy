CTS-ircdeploy
========================

Below you will find basic setup and deployment instructions for the CTS-
ircdeploy project. To begin you should have the following applications
installed on your local development system:

- Python = 2.7.*
- `pip >= 1.1 <http://www.pip-installer.org/>`_
- `virtualenv >= 1.7 <http://www.virtualenv.org/>`_
- `virtualenvwrapper >= 3.0 <http://pypi.python.org/pypi/virtualenvwrapper>`_

The deployment uses SSH with agent forwarding so you'll need to enable agent
forwarding if it is not already by adding ``ForwardAgent yes`` to your SSH
config.


Getting Started
------------------------

To setup your local environment you should create a virtualenv and install the
necessary requirements::

    mkvirtualenv cts-ircdeploy
    $VIRTUAL_ENV/bin/pip install -r $PWD/requirements.txt
