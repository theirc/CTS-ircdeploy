Installing CTS on a new EC2 server
==================================

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

#. If needed, :doc:`define a new environment <environments>`.

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
