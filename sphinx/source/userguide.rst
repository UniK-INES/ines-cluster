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
it is not possible to add a direct route into the cluster. For that we have a workaround that you can find in section "Without Route".

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

Change into the workstation directory and run ``./cluster_start``. The script will now boot the remaining client modules.


Without a route
-------------------
