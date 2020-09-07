User Guide
************************

Connect to one of the Fachgebiet's network outlets, the **nostromo** wifi or the `University's VPN <https://www.uni-kassel.de/its-handbuch/netzinfrastruktur/cisco-anyconnect-client.html>`_.

Powering on the cluster
------------------------------

Turn on the server module by activating the electrical outlet. In your web browser open `<http://141.51.123.42>`_ and login with the "Admin" account. You will see an item called "Schaltaktor RP-Cluster" which controlls the electrical outlet the cluster is connected to. Press the On button. 

The server module will power on the client modules, perform some self tests and turn them off again. Afterwards the client modules get booted one by one according to their geographical position. There is a :ref:`firmware issue <Known Problems>` keeping a lot of client modules from downloading their root partition. We will fix that with a helper script after we added the necessary routes.


.. note:: It is important to wait some time at this point as the client modules should not access the root partition at the same time.

.. todo:: Add testing if the client modules successfully booted with a side effect on the server module

Routing
----------------

In order to communicate with the client modules directly you need a route into the cluster. This means, the packages from your workstation addressed to the client modules (10.42.0.x) need a route to the server module. Under some circumstances 
it is not possible to add a direct route into the cluster. For that we have a workaround that you can find in section :ref:`Without Route <Without a route>`.

Check for a route
^^^^^^^^^^^^^^^^^^^^^

On linux based operating systems you can use one of the following commands:

.. code-block:: bash

	sudo route
	# alternatively
	sudo ip route

Output (your network interface names might differ):

.. code-block:: bash

	# 10.42.0.0       192.168.1.111   255.255.255.0   UG    0      0        0 wlan0
	# Alternatively
	# 10.42.0.0/24 via 141.51.123.55 dev eth0

If the route is not present yet you can try adding it manually.

.. code-block:: bash

	sudo route add 10.42.0.0 mask 255.255.255.0 141.51.123.55
	# alternatively when you are connected via wifi
	sudo ip route add 10.42.0.0/24 via 192.168.1.111

We can test the route with pinging the server module.

.. code-block:: bash

	ping 10.42.0.250

If you get a response you can ignore the next step.

Adding a route manually
^^^^^^^^^^^^^^^^^^^^^^^^^^

If you are connected to the WiFi

.. code-block:: bash

	sudo route add 10.42.0.0 mask 255.255.255.0 192.168.1.111
	# alternatively
	sudo ip route add 10.42.0.0/24 via 192.168.1.111

else

.. code-block:: bash

	sudo route add 10.42.0.0 mask 255.255.255.0 141.51.123.55
	# alternatively
	sudo ip route add 10.42.0.0/24 via 141.51.123.55

Try pinging the server module again.

.. code-block:: bash

	ping 10.42.0.250

If the server module is responding at this point go to :ref:`With a route` or else to :ref:`Without a route`.

With a route
-------------------

With a working route into the cluster you can directly use every script provided in the workstation directory of the repository on your computer. The easiest way to receive the scripts is cloning the respository ``git clone https://github.com/UniK-INES/ines-cluster.git``.

Dependencies
^^^^^^^^^^^^^^^^

We install the dependencies

.. code-block:: bash

	sudo apt-get install python python-pip fping -y
	pip install websocket-client

Starting the remaining modules
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Change into the workstation directory and run ``./cluster_start``. The script will now boot the remaining client modules.


Shutting down the cluster
^^^^^^^^^^^^^^^^^^^^^^^^^^

* Shut down the client modules

.. code-block:: bash

	# workstation directory
	./cluster_shutdown

* Wait until the client modules are turned off. You can check with nmap

.. code-block:: bash

	nmap -sP 10.42.0.0/24
	# Output should not list any ips in range 10.42.0.1 - 10.42.0.60

* Shut down the server module

.. code-block:: bash

	ssh pi@141.51.123.55

* Use the Homematic module to power off the socket.

Without a route
-------------------

Since we don't have a direct route into the cluster and to the client modules we connect to the Homematic module first where a static route to the server module exists.

.. code-block:: bash

	route
	# 10.42.0.0       141.51.123.55   255.255.255.0   UG    0      0        0 eth0


The ``/opt/cluster_scripts`` directory contains all necessary scripts for managing the cluster.

+---------------------+---------------------------------------------------------+
| Command             |                                                         |
+=====================+=========================================================+
| ./c_start           | Starts the remaining client modules                     |
+---------------------+---------------------------------------------------------+
| ./c_shutdown        | Shuts down the client modules                           |
+---------------------+---------------------------------------------------------+
| ./c_temperature     | Provides you CPU/GPU temperature of the clients         |
+---------------------+---------------------------------------------------------+

.. note:: The Raspberry Pi modules have a hard limit of 85°C and a soft limit of 60°C. After reaching 60°C the `clock speed is reduced by 200MHz and the operating voltage is slightly reduced <https://www.raspberrypi.org/documentation/hardware/raspberrypi/frequency-management.md>`_.


Executing commands on the server module (terminal)
---------------------------------------------------

Connect to the University's VPN and ssh into the server module

.. code-block:: bash

	ssh pi@141.51.123.55
	# Single command

In a script

.. code-block:: bash

	ssh pi@141.51.123.55 'current_path=$(pwd); echo $current_path'
	

Executing commands on client modules (terminal)
------------------------------------------------

When you are connected with the University's network or are using the WiFi you can directly connect to each client module.

.. code-block:: bash

	ssh pi@10.42.0.1
	# Single command

A quick way to run multiple commands on a node is to connect the commands with the ; operator.

.. code-block:: bash
	
	ssh pi@10.42.0.1 'echo $HOSTNAME; pwd'
	
You can use the following syntax to run commands on multiple nodes. 

.. code-block:: bash

	for i in $(seq 1 10); do
		ssh pi@10.42.0.$i 'echo $HOSTNAME'
	done
	
This will only work if you have a route into the cluster and all addressed nodes are R3 modules. In order to work on all nodes including the Zero modules you can use a script like this.

.. code-block:: bash

	# Download global_functions in master branch and source it
	source global_functions
	for i in $(seq 1 60); do
		currentnode=$(nodestring $i)
		currentip=$(get_ip_for_node $currentnode)
		ssh pi@$currentip 'echo $HOSTNAME'
	done

Executing commands on client modules with the provided scripts
---------------------------------------------------------------

With a route you can use the toolchain to upload and run your software on the nodes.

* Copy your ssh key to the server module so there won't be any password questions in the scripts we run later.

.. code-block:: bash

	ssh-copy-id outsider@141.51.123.55

* Create a new directory for your scripts or simulation files on the server node

.. code-block:: bash

	ssh outsider@141.51.123.55 'mkdir /pxe/meta/simulation/YOURSIMULATIONNAME'
	
* Upload via rsync

.. code-block:: bash

	rsync -r -e ssh /path/to/your/simulation/ outsider@141.51.123.55:/pxe/meta/simulation/YOURSIMULATIONNAME
	
.. note:: You can also use scp for uploading your simulation.

* Distribute your scripts or simulation to the desired nodes

.. code-block:: bash

	# You can use multiple single nodes or a range of nodes divided by semicolon
	ssh outsider@141.51.123.55 '/pxe/meta/sim_to_nodes "YOURSIMULATIONNAME" "4-6;9"'
	# The script will copy your simulation directory to the individual content directories of the specified nodes
	
Alternative in R

* Installing dependencies

.. code-block:: bash

	sudo apt-get install -y libssh-dev
	sudo -i R
	# In R shell
	install.packages("ssh")
	require("ssh")
	... (loaded successfully)
	q()

* Within your R script or console

.. code-block:: R

	R
	require("ssh")
	session <- ssh_connect("outsider@192.168.1.111")
	out <- ssh_exec_wait(session, command = 'mkdir /pxe/meta/simulation/YOURSIMULATIONNAME')
	path <- "/path/to/YOURSIMULATIONNAME"
	files <- dir(path)
	for (f in files) {
	out <- scp_upload(session, paste(path, f, sep="/"), '/pxe/meta/simulation/YOURSIMULATIONNAME', verbose = TRUE)
	}
	out <- ssh_exec_wait(session, command = '/pxe/meta/sim_to_nodes "YOURSIMULATIONNAME" "4-6;9"')

.. TODO:: Testing and running part in bash and R