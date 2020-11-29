Docker
******************

In the near future we would like to run docker on the Raspberry Pi nodes. Even though this is generally possible with Raspbian and there are even operating systems like HyperiotOS specializing on running docker containers, we face several problems when it comes to the cluster. For example the nodes' root partition is mounted over an nfs filesystem lacking copy on write which docker absolutely requires. Another problem is the limited main memory available on the nodes since the operating system is kept exclusively in the RAM.

We identified three different options so far that could work on the cluster. This page intends to keep track of the progress.

General todo list:

* Take one node x as test node
* Give x its own boot partition on sevastopol (tftp configuration)
* Duplicate pxe root partition and use the duplicate exclusively on x
* Include the boot partition in /etc/fstab
* Update/Upgrade the root partition for x

Docker on sd cards
------------------

In later docker versions it is possible to keep the docker root on a different storage. Every node has an unused sd card that could be used to store the docker containers.

What needs to be done:

1. Script that mounts the sd cards on nodes (ssh)
2. Install docker
3. If apt-get does not work, compiling it with gcc (binaries can be used for every single node later on)
4. Change docker configuration so the container root is on the sd card
5. Start container
6. If failure, try to move everything related to docker (binary, configuration, etc) to sd card
7. If success, compress every step into bash script so it can be done automatically on other nodes

Docker via vfs
----------------

VFS as an overlay file system could be used to provide the COW functionality.

What needs to be done:

1. Install VFS on x
2. Find out path where docker saves containers
3. Put the overlay over path
4. Trials
5. If failure, add overlay for everything docker related
6. If success, automate via bash script

Changing the way we boot
-------------------------

The nodes can also be booted with a standard Raspbian OS stored to the local sd cards.

What needs to be done:

1. Information on how to install os remotely (ssh)
2. Identify the essential manufactorer's scripts for powering on the nodes (should be 3 on sevastopol)
3. Build an image including everything
4. Scripts for deploying on every node
5. Single out second test node y
6. Trials
7. Automate process so os can be rolled out to every single node
8. Changes to nfs server
9. Additional ssh scripts for controlling the cluster (zero scripts as base)
