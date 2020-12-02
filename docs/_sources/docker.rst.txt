Docker
******************

In the near future we would like to run docker on the Raspberry Pi nodes. Even though this is generally possible with Raspbian and there are even operating systems like HyperiotOS specializing on running docker containers, we face several problems when it comes to the cluster. For example the nodes' root partition is mounted over an nfs filesystem lacking copy on write which docker absolutely requires. Another problem is the limited main memory available on the nodes since the operating system is kept exclusively in the RAM.

We identified three different options so far that could work on the cluster. This page intends to keep track of the progress.

General todo list:

* Take one node x as test node

1. Make sure no node is running

.. code-block:: bash

	nmap -sP 10.42.0.0/24
	# ..
	/home/client/python powerall.py off 1 60

* Give x its own boot partition on sevastopol (tftp configuration)

1. Backup dnsmasq.conf

.. code-block:: bash

	sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.20201202

2. Activate individual tftp-root directories based on ip address

.. code-block:: bash

	sudo nano -w /etc/dnsmasq.conf
	# Add
	tftp-unique-root=ip


3. Prepare directory and clone boot partition

.. code-block:: bash

	sudo mkdir /pxe/boot/10.42.0.2
	sudo rsync -arv --exclude=10.42.0.2 /pxe/boot/ /pxe/boot/10.42.0.2/

4. Prepare directory and clone root partition

.. code-block:: bash

	sudo mkdir /pxe/root_node02
	sudo rsync -arv /pxe/root/ /pxe/root_node02/
	# This will take some time


4. Edit cmdline.txt so node02 will boot a different root partition

.. code-block:: bash

	sudo nano -w /pxe/boot/10.42.0.2/cmdline.txt
	# Change 10.42.0.250:/pxe/root to 10.42.0.250:/pxe/root_node02

5. Boot node02 and touch a file

.. code-block:: bash

	python /home/pi/client/powerall.py on 2 2
	ssh pi@10.42.0.2
	touch test_file_node02
	exit
	ls /pxe/root_node02 | grep test_file_node02
	# If the file exists booting from the new root partition was successful

.. note:: There were some problems when this method was tested for the first time. The node was only be able to boot after several attempts. Maybe todo in the future if problems remain.
	
Alternatively the boot directories can also be provided based on the mac address. For that modify steps 2. and 3.

1. Get mac address for node02

.. code-block:: bash

	cat /pxe/meta/mac_nodes | grep -oP '^2[^0-9].*$'


2. In /etc/dnsmasq.conf add an individual directory for the boot partition for node02 (`<https://stackoverflow.com/questions/40008276/dnsmasq-different-tftp-root-for-each-macaddress>_`)

.. code-block:: bash

	# /etc/dnsmasq.conf
	tftp-unique-root=mac

2. Get mac address for node02

.. code-block:: bash

	cat /pxe/meta/mac_nodes | grep -oP '^2[^0-9].*$'

3. Create the directory with lowercase letters and zero padded digits.

* Include the boot partition in /etc/fstab

1. Connect to node02

.. code-block:: bash

	ssh pi@10.42.0.2

2. Change the /etc/fstab on node02

.. code-block:: bash

	sudo nano -w /etc/fstab
	# Add 10.42.0.250:/pxe/boot/10.42.0.2 /boot nfs defaults,vers=3 0 0
	sudo mount -a

3. Verify

.. code-block:: bash

	ls /boot
	# Should list the contents of /pxe/boot/10.42.0.2 on sevastopol

* Update/Upgrade the root partition for x (dirty)

1. Backup the root partition

.. code-block:: bash

	# On Sevastopol
	sudo /bin/bash
	mkdir /pxe/root_node02_backup
	rsync -avr /pxe/root_node02/ /pxe/root_node02_backup/
	# This will take some time

2. Flush all iptables rules

.. code-block:: bash

	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -t mangle -F
	iptables -t mangle -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT

3. Add all accepting rules

.. code-block:: bash

	# Allow established connections
	iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
	
	# Masquerade
	iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

4. Connect to node02 and update/upgrade

.. code-block:: bash

	ssh pi@10.42.0.2
	sudo /bin/bash
	apt-get update
	apt-get full-upgrade --dry-run > ~/full_upgrade_list
	apt-get full-upgrade 2>&1 | tee ~/full_upgrade





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
