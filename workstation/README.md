# Workstation context
These scripts should be used outside the cluster. Make sure you have a valid route into the cluster.

```
route
# or
ip route
```

Adding a route:

```
route add -net 10.42.0.0 netmask 255.255.255.0 gw 192.168.1.111
# or
sudo ip route add 10.42.0.0/24 via 192.168.1.111
```


## cluster_start

Usage: `./cluster_start`

Dependencies: Python (2 or 3), websocket client, fping, controll.py

Description: This script will ping every client module. If there is answer the script will use the manufactorer's software to power off the module, wait some time and power it on again.

## cluster_server_ssh_mount

Usage: `. cluster_server_ssh_mount root|pxe on|off`

Dependencies: sshfs

Description: This script creates a temporary directory and mounts either the server module's root partition or the client modules' root partition (pxe directory on server module). On successful mount it sources the global_functions file into the bash environment. The directory is deleted when you unmount.

## cluster_shutdown

Usage: `./cluster_shutdown`

Dependencies: python

Description: Power off all modules