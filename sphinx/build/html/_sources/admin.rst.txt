Administration
************************

This part gives an overview about the adminstration of the cluster. Main focus is on the server module since the nodes are using space on the server module's sd card to boot. Setting up a test system gives you the opportunity to recreate the system with a minimal amount of Raspberry Pi modules. It provides an insight into the internals and can be used (almost) equivalent to the productive system. Should you run into problems the Diagnosis section should be the first point to start. Troubleshooting lists some error scenarios that occur often while working with the system.

Detailed Booting Process
------------------------------

- All modules are started
- The server module performs tests on the client modules, turns them all out again and starts them according to their :ref:`geographical position <Geographical Position>` (1-60)
- When the clients start t
- After receiving an ip address they request the boot partition via tftp
- When the firmware was loaded on the clients they try to mount the root partition
- The root partition is provided by the server module's nfs server
- When mounting was successful the client modules start the operating system
- The LED on a client module is powered on when all services were started
- The client will additionally mount its individual content directory


Servermodule
------------------------------

Backup and Restore
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The contents of the server module are regularly backuped onto the department's disk station. The images are named after their backup date. The easiest way to backup and restore is by using img-files containing the boot and 
root partition. Please note: the older backups were done with rsync in combination with tar and gunzip. When you intend to restore an older image (for example the factory default image) a lot of additional work like modifying fstab, setting missing symlinks, etc will be required.

For both backup and restore procedures:

* Shutdown the client modules by either ssh'ing into the running ones and shutting them down or using the provided bash scripts
 
* Shutdown the server module

* Open the Homematic control panel in your web browser
* Deactivate the electrical outlet
* Remove the sd card from the server module

On your workstation:

* Insert the server module's sd card
* Find out its name

.. code-block:: bash

	lsblk
	# We assume it is /dev/sdb

Backup
=================

* We use dd to backup both partitions. You can add the partitions name at the end (for example ``/dev/sdb1``) if you are only interested in a particular partition.

.. code-block:: bash

	sudo dd bs=4M of=/dev/sdb status=progress | gzip > "$(date '+%Y-%m-%d server module backup').img.gz"

* Upload the created image to the disk station

	

Restore
=================

When you intend to use a new sd card and restore an older image, take a look into the ``/etc/fstab`` and overwrite the old identifier. Usually the identifier of the card keeps the name when exchanged between different modules.

* Download the image from the department's diskstation. The samba mount requires root permission so open a root shell and install the dependencies.

.. code-block:: bash

	sudo /bin/bash
	apt-get install cifs-utils keyutils -Y

* Create a directory for mounting.

.. code-block:: bash

	mkdir mnt_diskstation

* Create a credential file.

.. code-block:: bash

	touch .smbcredentials
	echo -e "username=YOURUSERNAME\npassword=YOURPASSWORD\ndomain=its-ad"

* Mount the directory with your credentials.

.. code-block:: bash

	sudo mount -t cifs //141.51.123.2/ines-cluster ~/mnt_diskstation/ -o credentials=~/.smbcredentials,iocharset=utf8,file_mode=0777,dir_mode=0777,vers=2.0

Troubleshooting since we are talking to a windows service: add -vvv as parameter to the mount command and check the syslog with dmesg

* The images of the server node are found in the server_node_backup directory. Download it to your workstation and unzip it.

.. code-block:: bash

	mkdir ~/tmp_img
	cp ~/mnt_diskstation/server_node_backup/'2020-08-13 server module backup.img.gz' ~/tmp_img
	cd ~/tmp_img
	gunzip '2020-08-13 server module backup.img.gz'

* Extract the partions and copy it to the new sd card

.. code-block:: bash

	sudo dd bs=4M if=imagefile.img of=/dev/sdb status=progress

* Mount the root partition of the sd card and make sure the identifier of the sd card in ``/etc/fstab`` is identical.


Troubleshooting

dmesg output
bad geometry: block count 7748608 exceeds size of device


Package dnsmasq
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The package includes the dhcp and tftp server. When powered on the client nodes will look for the first dhcp in the local network and request an ip address and hostname.

Debugging packets
=====================

We can get information about the dhcp handshake with tcpdump.

.. code-block:: bash

	sudo tcpdump -i eth0 port bootpc
	# Output will look like this
	12:46:31.983064 IP 0.0.0.0.bootpc > 255.255.255.255.bootps: BOOTP/DHCP, Request from 10.42.0.2, length 322
	12:46:33.987601 IP 10.42.0.250.bootps > node02.cluster.bootpc: BOOTP/DHCP, Reply, length 341
	# More detailed in combination with the command below
	sudo tcpdump -vvveni eth0 portrange 67-68
	
Additionally you can use your own computer to send a dhcp broadcast into the cluster net.

.. code-block:: bash

	sudo nmap --script broadcast-dhcp-discover 255.255.255.255 -p67

DHCP Configuration
=====================

The ip addresses are configured in /etc/dnsmasq.d/mac_table. They are set accoring to the nodes' geographical position. The Zero modules don't have an ethernet interface and connect to an external wifi so they are not listed in the file.

.. code-block:: bash

	dhcp-host=b8:27:eb:fc:6a:59,node35,10.42.0.35,infinite
	
After getting an ip address the client will request the boot partition.

.. code-block:: bash

	tail -f /var/log/daemon.log
	# Output
	Sep 15 12:46:34 sevastopol dnsmasq-tftp[603]: file /pxe/boot/bootsig.bin not found
	Sep 15 12:46:34 sevastopol dnsmasq-tftp[603]: sent /pxe/boot/bootcode.bin to 10.42.0.2
	Sep 15 12:46:34 sevastopol dnsmasq-tftp[603]: file /pxe/boot/27e247cc/start.elf not found
	Sep 15 12:46:34 sevastopol dnsmasq-tftp[603]: file /pxe/boot/autoboot.txt not found
	Sep 15 12:46:34 sevastopol dnsmasq-tftp[603]: sent /pxe/boot/config.txt to 10.42.0.2
	Sep 15 12:46:34 sevastopol dnsmasq-tftp[603]: file /pxe/boot/recovery.elf not found
	Sep 15 12:46:35 sevastopol dnsmasq-tftp[603]: sent /pxe/boot/start.elf to 10.42.0.2
	Sep 15 12:46:35 sevastopol dnsmasq-tftp[603]: sent /pxe/boot/fixup.dat to 10.42.0.2
	Sep 15 12:46:35 sevastopol dnsmasq-tftp[603]: file /pxe/boot/recovery.elf not found
	Sep 15 12:46:35 sevastopol dnsmasq-tftp[603]: sent /pxe/boot/config.txt to 10.42.0.2


NFS Server
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Provides the root partition /pxe/root and the individual content directory for the nodes. The directories are set in /etc/exports. Changes have to be reimported with exportfs -ra.

User outsider
^^^^^^^^^^^^^^^^^^^^^^

The user account "outsider" on the server module and the client modules is used to setup and run new simulations.

Setup
==========

.. code-block:: bash

	sudo /bin/bash
	useradd -m -g pi outsider
	# Disabling status messages when connecting via ssh
	echo -e "outsider\noutsider" | passwd outsider
	touch /home/outsider/.hushlogin && chown outsider:pi /home/outsider/.hushlogin

Debug
=========

.. code-block:: bash

	cat /etc/passwd | grep outsider
	# outsider:x:1221:1221::/home/outsider:/bin/bash
	cat /etc/group | grep outsider
	# adm:x:4:pi,outsider
	# dialout:x:20:pi,outsider
	# sudo:x:27:pi,outsider
	# plugdev:x:46:pi,outsider
	# users:x:100:pi,outsider
	# input:x:101:pi,outsider
	# netdev:x:108:pi,outsider
	# pi:x:1000:outsider
	# outsider:x:1221:

Homematic
------------------------------

The cluster is powered by an electrical socket that is controlled by the debmatic software running on this R4 module (`<http://141.51.123.42>`_).

.. note: Always make sure the server module is not running anymore when you power off the socket.

Additionally the Homematic module provides date and time information for the nodes. For that a ntp server is used.

1. Installation
::

	sudo apt-get install ntp

2. Disable systemd's timesyncd service
::

	systemctl stop systemd-timesyncd
	systemctl disable systemd-timesyncd

3. Configuration is found in ```/etc/ntp.conf```  

On nodes:

1. Add ntp server
::

	nano /etc/systemd/timesyncd.conf
	# NTP=141.51.123.42

2. Restart timesyncd service
::

	sudo systemctl restart systemd-timesyncd.service

3. Time and date should be correct now
::

	timedatectl


Client modules
------------------------------

In the manufactorer's server module configuration (standard configuration image) the nodes are booted simply by turning on the electricity to each module. There are three services responsible started by systemd on boot on the server module. This means whenever the server module is booted every single client node receives an "electricity off / on" signal. The server module sends the boot partition via TFTP and consequently the boot partition is not available on the nodes after they finished booting which makes it impossible to use programms like apt-get to install new software out of the box.

There are multiple ways to fix this problem:

* Mounting the boot partition after the boot process was finished on nodes via /etc/fstab
* Mounting it manually by script
* Change the /boot directory in the root partition on server node into a simlink

Mounting the boot partition with an entry in /etc/fstab
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Make sure the boot partition gets exported by the nfs server

.. code-block:: bash

	showmount -e

* Add the path to the boot partition in `/etc/fstab``

.. code-block:: bash

	sudo nano -w /etc/fstab
	# 10.42.0.250:/pxe/boot /boot nfs defaults,vers=3 0 0

The boot partition will be mounted after the next boot.

.. warning::
	If the boot partition is not mounted an `apt-get upgrade` can corrupt the root partition.


Setting a custom boot partition for a single node
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The root partition is set in cmdline.txt in `/pxe/boot`. In order to use an individual root partition for a specific node we need the TFTP server to distribute an individual boot partition to the node. This enables testing without corrupting the root image for all nodes.

1. Turn off all nodes and get a root shell

.. code-block:: bash

	nmap -sP 10.42.0.0/24
	# ..
	/home/client/python powerall.py off 1 60
	sudo /bin/bash


2. Backup and edit TFTP configuration

.. code-block:: bash

	bk_date=$(date +"%y%m%d%s")
	cp /etc/dnsmasq.conf "/etc/dnsmasq.conf.$bk_date"
	nano -w /etc/dnsmasq.conf
	# Find or add
	tftp-unique-root=ip

3. The directory for the individual boot partition unfortunately has to be in the main TFTP directory

.. code-block:: bash

	# Based on the ip address
	mkdir /pxe/boot/10.42.0.2
	# Duplicate the content
	rsync -arv --exclude=10.42.0.2 /pxe/boot/ /pxe/boot/10.42.0.2/

4. Clone the root partition

.. code-block:: bash

	mkdir /pxe/root_node02
	rsync -arv /pxe/root/ /pxe/root_node02/
	# This will take some time

5. Edit cmdline.txt

.. code-block:: bash

	nano -w /pxe/boot/10.42.0.2/cmdline.txt
	# Change 10.42.0.250:/pxe/root to 10.42.0.250:/pxe/root_node02

6. Start node02 and test

.. code-block:: bash

	python /home/pi/client/powerall.py on 2 2
	ssh pi@10.42.0.2
	touch test_file_node02
	exit
	ls /pxe/root_node02 | grep test_file_node02
	# If the file exists booting from the new root partition was successful


.. note:: It took several attempts to boot the indidivual boot partition in the first run.
	

Hostname
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When a client module is booted the eth0 hardware address is used to determine their geographical position. The lookup table is located in ``/opt/mac_nodes``.

.. code-block:: bash
	
	read MAC </sys/class/net/eth0/address
	cat /opt/mac_nodes | grep $MAC
	# Output
	2       b8:27:eb:e2:47:cc

The geographical position is then used to generate a hostname for the specific client module. The hostnames are formatted with leading 0s when the geographical position is smaller than 10.

.. code-block:: bash

	node01
	node02
	..
	node10
	node11
	..

When the hostname is known the client module tries to mount their individual content directory. This happens during booting in ``/opt/mount_content.sh``.

.. code-block:: bash

	.. sudo mount -t nfs -o soft 10.42.0.250:"$CONTENT_DIR" "$MOUNT_DIR"; then ..

Since root permissions are needed to mount there is an exception for ``/opt/mount_content.sh`` in ``/etc/sudoers``.

.. code-block:: bash

	cat /etc/sudoers
	# Output
	..
	%pi     ALL=NOPASSWD: /opt/mount_content.sh
	..

Individual content directory
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The simulations for the clients to run are stored in their individual content directory. On the server module they are located in ``/pxe/nodes`` and are mounted on the clients in /opt/individual_content. Inside the directory a symlink ``lastrun`` points to the output file of the last run simulation.

The output file contains all informations about the lastrun and is available during run time. The file descriptors (FDPARENT and FDCHILD) can be used to read standard output/error from the ``/opt/starter`` script and the command/simulation the client is running currently.

.. code-block:: bash

	cat /opt/individual_content/lastrun
	# Output
	PARENTPID:                              26301
	FDPARENT:                               10
	FDCHILD:                                11
	COMMAND(default):                       java -classpath /home/pi/ EndlessTest
	CHILDPID:                               26344
	CHILDRET:                               123
	Run finished 17h15m56s 19.08.2020

For an overview of all commands/simulations run by the client node you can list the ``/opt/individual_content/starter`` directory.

.. code-block:: bash

	ls /opt/individual_content/starter
	# Output is formatted by date _ time


Setting Up A Testsystem
------------------------------

In most use cases it's beneficial to have a test system that works equivalent to the cluster where changes are made locally before they get introduced to all modules on the cluster eg our productive system.
In this section we go through the necessary steps to create a system that provides that functionality. Overall there are four RaspberryPi modules needed.

* A RaspberryPi 3+ (or comparable) with SD card for providing the WiFi
* A RaspberryPi 3+ with SD card acting as the server module
* A RaspberryPi 3+ acting as client module
* A RaspberryPi Zero with SD card acting as client module

Preparing the SD cards and installing Raspbian
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. Get the latest raspbian lite image
::

	mkdir -p ~/raspbian-lite && cd "$_"
	wget https://downloads.raspberrypi.org/raspbian_lite_latest

2. Unzip it. There should be an img-file in your current directory now.
::

	unzip raspbian_lite_latest

2. Insert your sd card and check out its name.
::

	lsblk

	mmcblk0     179:0    0  29,8G  0 disk 
	└─mmcblk0p1 179:1    0  29,8G  0 part

3. Sometimes the partitions of the card get auto mounted. We need them unmounted.
::

	mount # look for your sd card
	umount /dev/mmcblk0p1

4. Copy the operating system to the sd card
::

	sudo dd bs=4M if=2019-04-08-raspbian-stretch-lite.img of=/dev/mmcblk0 conv=fsync status=progress
	
.. note:: The dd-command expects the device name not a partition name.

5. Mount the root filesystem and enable ssh
::

	sudo mkdir -p /mnt/rasp_root
	sudo mount /dev/mmcblk0p2 /mnt/rasp_root
	touch /mnt/rasp_root/boot/ssh
	
6. Expanding the file system

Open the sd card in fdisk and print the partition table::

	sudo fdisk /dev/mmcblk0
	Press p

Sample output:
::

	Device         Boot Start     End Sectors  Size Id Type
	/dev/mmcblk0p1       8192   96042   87851 42,9M  c W95 FAT32 (LBA)
	/dev/mmcblk0p2      98304 3522559 3424256  1,6G 83 Linux

Save the root partition Start value (98304 in sample output), delete the partition and recreate it::

	Press d for delete
	Press 2 for partition 2
	Press n for new partition
	Press p for primary partition
	Press 2 for partition 2
	Enter the start value 98304 from above
	Press Enter for default (partition will use available space)
	Answer no when asked if you want to remove the partition's signature
	Press w to write out the partition table

.. note:: This works because we don't format the partition so the data on the card is not overwritten and remains readable.

Generate and set locale
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. Boot the module and connect via ssh
::

	ssh pi@192.168.0.123
	
	Login with pi/raspberry

2. Generate the locale
::

	sudo sed -r -i 's/# (de_DE.UTF-8 UTF-8)/\1/' locale.gen
	sudo locale-gen de_DE.UTF-8
	
3. Check that it was generated and update
::

	locale -a | grep -i de_DE.utf8
	sudo update-locale LANG=de_DE.UTF-8 LC_MESSAGES=POSIX

.. note:: We set LC_MESSAGES=POSIX so the system messages don't get translated. The updated locale will be available after the next reboot. If you run into problems setting the locale correctly you 
	can set LC_ALL to the locale of your choice. All other LC variables will be overwritten by that value.

4. In recent Raspbian versions the Wifi interface will be disabled if the country variable is not set in /etc/wpa_supplicant/wpa_supplicant.conf
::

	sudo sed -i '1i country=DE' /etc/wpa_supplicant/wpa_supplicant.conf

At this point we have an image containing Raspbian that can be used to boot any of the R3 modules. We backup the image and distribute it to the server module. The other R3 module left will be 
booted over Netboot (TFTP) and NFS so it does not need an sd card present.

1. Create a directory for storing the images and change to it
::

	mkdir -p ~/testsystem/images && cd $_

2. Find the name of your sd card
::

	lsblk
	
3. Backup the content (your sd card's name may differ)
::

	sudo dd bs=1M if=/dev/mmcblk0 of=./raspbian-testsystem-generic.img conv=fsync status=progress

This image can be used to restore any unwanted changes. You can use the last three steps to make backups of your work at any time desired. Restoring is pretty simple but takes time.
::

	sudo dd bs=1M if=./raspbian-testsystem-generic.img of=/dev/mmcblk0 conv=fsync status=progress

4. Changing the image without transfering and booting it to/from sd card
.. todo:: todo

General steps for the server and the wifi module

Connect via ssh
::

	ssh pi@192.168.0.123
	Login with pi/raspberry

1. Get a root shell and change the root account's passwd
::

	sudo su
	passwd root

.. note:: We assume the password for the root account was set to unikassel.

2. Update the operating system
::

	apt-get update -y && apt-get upgrade -y

3. Create a new user. It is important to set a unique user id since NFS and consequently netboot will rely on having matching user ids on clients and server.
::

	getent passwd 1234 # Should return an empty line meaning the userid is not present
	useradd -u 1234 -G adm,dialout,sudo,plugdev,users,input,netdev -s /bin/bash nfsuser
	mkhomedir_helper nfsuser
	passwd nfsuser # Set the new user's password. We assume unikassel.
	
4. Soft disable the pi user account.
::

	usermod -s /bin/false pi
	passwd -l pi

At this point the default user pi won't be able to login anymore. You might want to reconnect with the newly created user.
	
The WiFi module
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The server module uses its ethernet interface for communicating with the R3 client modules. As consequence we use the wireless interface for communicating with it. The wifi itself is provided by an additional 
RaspberryPi module that is set up with packages hostapd and dnsmasq. There are multiple ways to go on from here.

1. Emulating the RaspberryPi with qemu and make changes locally
2. A container solution like systemd-nspawn
3. Native chroot with additional libs
4. Working on the module itself via ssh
5. Working on the module locally

Options 1 to 3 require a complicated setup before we are able to start therefor we focus on options 4 and 5. Insert one of the prepared sd cards into one of the R3 modules and connect it to your local setup via 
ethernet interface. Find out its IP address and connect via ssh. For easier reading we assume that address to be 192.168.0.123.
::

	ssh pi@192.168.0.123
	Login with pi/raspberry

.. note:: Sometimes the locale isn't set correctly on first boot so you are writting with an English keyboard layout (y -> z)

1. Get a root shell and set the hostname.
::

	sudo su
	echo "testwifi" > /etc/hostname
	echo -e "127.0.0.1\ttestwifi" >> /etc/hosts

2. Update Raspbian and install the required packages.
::

	apt-get update -y && apt-get upgrade -y
	apt-get install dnsmasq hostapd nmap -y

3. In recent Raspbian versions hostapd gets masked by systemd (bug filed at https://github.com/raspberrypi/documentation/issues/1018) so we need to unmask and enable it
::

	systemctl unmask hostapd
	systemctl enable hostapd

4. Make sure both services are stopped and reboot
::

	systemctl stop dnsmasq hostapd
	reboot
	
6. Configure a static IP for the wireless interface
::

	echo -e "# Static IP for wifi interface\ninterface wlan0\n\tstatic ip_address=192.168.0.1/24\n\tnohook wpa_supplicant" >> /etc/dhcpcd.conf

Alternatively by hand with nano
::

	nano -w /etc/dhcpcd.conf
	# Add these lines at the end of the file
	interface wlan0
		static ip_address=192.168.0.1/24
		nohook wpa_supplicant

7. Reload and restart dhcpcd
::

	sudo su
	systemctl daemon-reload
	service dhcpcd restart

8. Backup the old dnsmasq config and set up the basics
::

	mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
	echo -e "interface=wlan0\n\tdhcp-range=192.168.0.1,192.168.0.20,255.255.255.0,infinite" > /etc/dnsmasq.conf

Alternatively by hand with nano
::

	nano -w /etc/dnsmasq.conf
	# Add these lines
	interface=wlan0
		dhcp-range=192.168.1.1,192.168.1.20,255.255.255.0,infinite

.. note:: In our productive system the Zero modules are connected to this wifi and use its dhcp server to get their hostnames. They are identified by their physical address. Since we only have one Zero 
	module in the test system changes are made easily by hand. In the productive system however an automatic approach is more convenient. You can look up the details in the corresponding section.

9. Configure hostapd base configuration and logging
::

	nano /etc/hostapd/hostapd.conf
	# Add these lines
	interface=wlan0
	driver=nl80211
	ssid=testwifi
	hw_mode=g
	channel=7
	wmm_enabled=0
	macaddr_acl=0
	auth_algs=1
	ignore_broadcast_ssid=0
	wpa=2
	wpa_passphrase=unikassel
	wpa_key_mgmt=WPA-PSK
	wpa_pairwise=TKIP
	rsn_pairwise=CCMP

::
	
	touch /var/log/hostapd.log
	chmod 666 !$
	nano /etc/default/hostapd
	# Look for #DAEMON_CONF
	DAEMON_CONF="/etc/hostapd/hostapd.conf"
	# Look for #DAEMON_OPTS
	DAEMON_OPTS="-dd -t -f /var/log/hostapd.log"

10. Start both services
::

	systemctl start hostapd dnsmasq

11. IP Forwarding and necessary iptables rules
::

	sed -i '/#net\.ipv4\.ip\_forward\=1/c\net\.ipv4\.ip\_forward\=1' /etc/sysctl.conf # activates ip forwarding in /etc/sysctl.conf
	iptables -t nat -A  POSTROUTING -o eth0 -j MASQUERADE
	sh -c "iptables-save > /etc/iptables.ipv4.nat"
	sed -r -i 's/^(exit 0)/\iptables-restore \< \/etc\/iptables\.ipv4\.nat\n\1/' /etc/rc.local
	iptables -t nat -L # this will check if the rules were applied

At this point devices can connect to a wifi (ssid: testwifi) and get their packages rerouted to the ethernet interface of that module.

The Server Module
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We have the wifi working and can move on to the server module. Remember the server module uses its ethernet interface supplying the R3 client modules with their operating system and its 
wireless interface for communicating with the outside world. So our goals in this section is preparing the ethernet interface and setup an nfs server. 

1. For that we copy our generic image to an sd card.
::

	sudo su
	mount /dev/mmcblk0p2 /mnt/rasp_root


2. Edit /etc/wpa_supplicant/wpa_supplicant.conf
::

	echo -e "\nnetwork={\n\tssid=\"testwifi\"\n\tpsk=\"unikassel\"\n}" >> /mnt/rasp_root/etc/wpa_supplicant/wpa_supplicant.conf

Alternatively by hand with nano
::

	nano -w /mnt/rasp_root/etc/wpa_supplicant/wpa_supplicant.conf
	# Add these lines
	network={
		ssid="testwifi"
		psk="unikassel"
	}

3. Create a directory structure for the client modules' operating system.
::

	mkdir -p /mnt/rasp_root/pxe/{root,boot,nodes,meta/{data,scripts}}

4. Create directories for mounting the partitions
::

	cd ~/testsystem
	mkdir -p mnt/{boot,root}

5. Find out where the partitions start.
::

	fdisk -l raspbian-testsystem-generic.img
	# Output
	Device                           Boot Start      End  Sectors  Size Id Type
	raspbian-testsystem-generic.img1       8192    96042    87851 42,9M  c W95 FAT32 (LBA)
	raspbian-testsystem-generic.img2      98304 62521343 62423040 29,8G 83 Linux
	
	# Take the values in the Start row and multiply them with the sector size
	expr 8192 \* 512
	# 4194304
	
	expr 98304 \* 512
	# 50331648
	
6. Mount the boot partition and copy it to the server module's pxe directory
::

	sudo mount -o loop,offset=4194304 raspbian-testsystem-generic.img mnt/boot
	sudo rsync -xa --progress ~/testsystem/mnt/boot/* /mnt/rasp_root/pxe/boot

.. note:: Without additional software you won't be able to mount both partitions at the same time.

7. Tell the R3 client modules where to find their root partition after booting by editing the cmdline.txt
::

	nano -w /mnt/rasp_root/pxe/boot/cmdline.txt
	# Replace content with (twice ctrl + k)
	dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=10.42.0.250:/pxe/root,vers=3 rw ip=dhcp elevator=deadline rootwait

.. note:: Be very careful with special characters in this file. Avoid using any unnecessary white spaces especially new line \n or tab \t.

8. Unmount the boot partition, mount the root partition copy the contents and unmount it again.
::

	umount ~/testsystem/mnt/boot
	sudo mount -o loop,offset=50331648 raspbian-testsystem-generic.img mnt/root
	sudo rsync -xa --progress ~/testsystem/mnt/root/* /mnt/rasp_root/pxe/root
	umount ~/testsystem/mnt/root

9. Enable SSH on the clients
::

	touch /mnt/rasp_root/pxe/root/boot/ssh

10. Make sure no process is still using the mount point and unmount the server module's sd card.
::

	unmount /mnt/rasp_root

At this point the server module's sd card is prepared for booting it up in one of our R3 modules. For connecting to it we use our already set up wifi. Connect your computer to the wifi, insert the 
server module's sd card in one of the R3 modules and boot it.
	
We can insert the sd card into one of the R3 modules now and boot it. Connect to our new wifi and find out the server module's ip address. We assume its 192.168.1.4 going forward.
::

	ssh nfsuser@192.168.1.4

1. Create necessary directories and install packages
::

	mkdir -p /pxe/{root,boot,nodes,meta/{data,scripts}}
	sudo su
	apt-get install tcpdump nmap dnsmasq nfs-kernel-server -y


2. Set the hostname.
::

	echo "testserver" > /etc/hostname
	echo -e "127.0.0.1\ttestserver" >> /etc/hosts

3. Configure a static ip address for the ethernet interface
::

	echo -e "# Static IP for ethernet interface\ninterface eth0\nstatic ip_address=10.42.0.250/24" >> /etc/dhcpcd.conf

4. Configure dnsmasq
::

	mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
	nano -w /etc/dnsmasq.conf
	# Add these lines
	interface=eth0 # the interface the dhcp server should listen on
	port=0
	dhcp-range=10.42.0.1,10.42.0.150,255.255.255.0,infinite
	log-queries
	log-dhcp
	enable-tftp # the tftp server will supply the boot partition for the clients
	tftp-root=/pxe/boot # the directory where the tftp server will look for the boot partition
	pxe-service=0,"Raspberry Pi Boot"

5. Export the pxe directory where the clients find their root partition
::

	echo -e "\n/pxe\t\t10.42.0.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash) 192.168.1.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports

Alternatively by hand via nano
::

	nano -w /etc/exports
	# Add these line
	/pxe            10.42.0.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash) 192.168.1.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)

.. note:: The no_root_squash parameter can be a security flaw. Without it, the clients will run into a kernel panic when they try to mount the root partition. We include 
	the 192.168.1.0 range because the Zero modules will mount their directories via the wireless interface. If you set different ips for your wifi module you need to change 
	the second part of the line.

6. Whenever you change the /etc/exports you need to reimport it
::

	sudo exportfs -ra
	# -a = export or deexport all directories
	# -r = reexport all directories and synchronize /var/lib/nfs/etab with /etc/exports

7. Finally we remove the references to the sd card in our clients' /etc/fstab
::

	sudo nano -w /pxe/root/etc/fstab
	# Remove all lines except the one starting with /proc

Debugging the netboot


The client modules
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You are now able to netboot an R3 client module with its ethernet interface connected to our server module. Connect the client's ethernet interface to 
the server module.

After that the client will go through its RaspberryPi `boot order <https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/bootflow.md>`_ and boot 
from the first device in the list that it finds.

.. note:: The module will boot from the first device it is able to identify and disregards entries lower in the list. Be careful when sd cards are present even if they don't have 
	the right partition scheme or file systems. If you encounter problems at this point, try removing the sd card.

The booting itself is done over Trivial File Transfer Protocol after the client received an ip address from the first DHCP server it encounters on the network. The package dnsmasq is responsible for both TFTP and DHCP and logs to 
/var/log/daemon.log.
::

	# Connect to the server module
	cd /var/log
	tail -n 50 daemon.log
	# or if you need more lines
	nano daemon.log
	
	# Output
	May  3 10:40:45 testserver *dnsmasq-dhcp*[496]: 653460281 DHCPDISCOVER(eth0) b8:27:eb:76:a6:1a
	..
	May  3 10:40:45 testserver *dnsmasq-dhcp*[496]: 653460281 DHCPOFFER(eth0) 10.42.0.17 b8:27:eb:76:a6:1a
	..
	May  3 10:40:55 testserver dnsmasq-tftp[496]: file /pxe/boot/b876a61a/start.elf not found
	May  3 10:40:55 testserver dnsmasq-tftp[496]: file /pxe/boot/autoboot.txt not found
	May  3 10:40:55 testserver dnsmasq-tftp[496]: sent /pxe/boot/config.txt to 10.42.0.17
	May  3 10:40:55 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery.elf not found
	May  3 10:40:56 testserver dnsmasq-tftp[496]: sent /pxe/boot/start.elf to 10.42.0.17
	May  3 10:40:56 testserver dnsmasq-tftp[496]: sent /pxe/boot/fixup.dat to 10.42.0.17
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery.elf not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: sent /pxe/boot/config.txt to 10.42.0.17
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/dt-blob.bin not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery.elf not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: sent /pxe/boot/config.txt to 10.42.0.17
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/bootcfg.txt not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: sent /pxe/boot/cmdline.txt to 10.42.0.17
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery8.img not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery8-32.img not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery7.img not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/recovery.img not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/kernel8.img not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/kernel8-32.img not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/armstub8.bin not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/armstub8-32.bin not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/armstub7.bin not found
	May  3 10:40:57 testserver dnsmasq-tftp[496]: file /pxe/boot/armstub.bin not found
	May  3 10:41:00 testserver dnsmasq-tftp[496]: sent /pxe/boot/kernel7.img to 10.42.0.17
	May  3 10:41:00 testserver dnsmasq-tftp[496]: sent /pxe/boot/bcm2710-rpi-3-b.dtb to 10.42.0.17
	May  3 10:41:00 testserver dnsmasq-tftp[496]: sent /pxe/boot/config.txt to 10.42.0.17


Problems with dnsmasq-dhcp can be debugged with tcpdump
::

	# Connect to the server module
	sudo tcpdump -i eth0 port bootpc
	# Start the client module
	
	# Output
	10:52:37.895478 IP 0.0.0.0.bootpc > 255.255.255.255.bootps: BOOTP/DHCP, Request from b8:27:eb:76:a6:1a (oui Unknown), length 320
	10:52:40.732978 IP 0.0.0.0.bootpc > 255.255.255.255.bootps: BOOTP/DHCP, Request from b8:27:eb:76:a6:1a (oui Unknown), length 320
	10:52:44.815790 IP 0.0.0.0.bootpc > 255.255.255.255.bootps: BOOTP/DHCP, Request from b8:27:eb:76:a6:1a (oui Unknown), length 320
	10:52:44.817322 IP 10.42.0.250.bootps > 10.42.0.17.bootpc: BOOTP/DHCP, Reply, length 344

No activity on the server's ethernet interface while you try netbooting an R3 client points to network issues. There is a `known bug <https://github.com/raspberrypi/firmware/issues/764>`_ where the 
RaspberryPi ignores answers from the DHCP server. Sending a broadcast ping can help.
::

	ping -b 10.42.0.255


On older modules netboot needs to be `enabled explicitly <https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/net_tutorial.md>`_. 
Sometimes it helps setting the program_usb_boot_mode even if R3+ modules should have it set already.

Problems with dnsmasq-tftp could have their reason in misconfiguration of the dnsmasq package. Check the corresponding sections and copy a clean boot 
partition to the server's /pxe/boot directory again.

When the logs show the desired output but the client module still does not show up
::

	# Connect to the server module
	nmap -sP 10.42.0.0/24
	# Output only the server module was found

something could have gone wrong with mounting the root partition. The easiest way from here is connecting the module with an HDMI cable to a monitor and check the output. Additionally (or in the case you 
can't simply connect a cable like in our productive system) you can debug the nfs server.

* Check if your directories were exported correctly

::

	# Connect to testwifi with your working machine. We assume the testserver's ip to be 192.168.1.4
	showmount -e 192.168.1.4
	# On the server locally
	showmount -e
	
	# Output should look similar
	Export list for testserver:
	/pxe 192.168.1.0/255.255.255.0,10.42.0.0/255.255.255.0

* Check if the nfsuser can mount the root partition

::

	# Connect to testwifi with your working machine. Next two lines only if you didn't already create nfsuser on your working machine.
	sudo useradd -u 1234 nfsuser
	sudo passwd nfsuser
	mkdir mnt
	sudo -u nfsuser sudo mount -o hard,nolock 192.168.1.4:/pxe/root mnt
	# output should list the nfs directory
	mount
	# check the content
	ls mnt



.. todo:: Cut that here.

Reconfigure the wireless interface
::

	wpa_cli -i wlan0 reconfigure
	iwconfig wlan0 # output should show our access point ESSID="testwifi"
	ifconfig wlan0 # output should show an ip address 192.168.1.x





Diagnosis
------------------------------


Troubleshooting
------------------------------

It is physically impossible to access the client modules' hdmi output because of the way the cluster is assembled. When all nodes are running it is also impossible to access the kernel logs with the current configuration since the nodes work concurrently on the same data stock. 


:Example:
	After booting the LED of a module stays off but the module is pingable.

:Conclusion:
	The problem occured between initiating the network interfaces and running /etc/rc.local (the location where the led is powered on)