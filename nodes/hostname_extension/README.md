# Hostname extension

In the manufactorer's configuration the nodes share the same hostname hence debugging becomes more complicated. As a solution the nodes in our cluster receive their hostname from the dhcpd on the server module. Additionally 
a mac table is maintained that enables the node to calculate its hostname by looking up a mac table. The mac table is synchronized by the server module's cron jobs.

## mount_content.sh

Usage: `/opt/mount_content.sh`

Dependencies: `/opt/meta/mac_nodes`

Description: After booting successfully the node mounts a directory outside its pxe root directory based on its own hostname. `/opt/individual_content` on the client points to `/pxe/nodes/<hostname>` on the server module. This is achieved by 
the following steps.

* The `mount_content.sh` script is copied to `/opt`
* The init script `client-nfs-mount` is placed into the node's `/etc/init-d` directory
```
#!/bin/bash
### BEGIN INIT INFO
# Provides:          client nfs mount
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable services provided by daemon.
### END INIT INFO

/bin/bash /opt/mount_content.sh start
```
* ssh into one node, make the script executable and add it to default runlevel
```
cd /etc/init.d
sudo chmod +x client-nfs-mount
sudo update-rc.d client-nfs-mount defaults
```

* An exception is added to `/etc/sudoers` since mounting requires root rights

```
# Backing up sudoers file
cp /etc/sudoers /etc/sudoers.bak
sudo visudo
# Look for "Allow members of group sudo to execute any command" and append this line
%pi     ALL=NOPASSWD: /opt/mount_content.sh

```

Optional: On some systems you will end up in vi if you run `visudo`. You can change the editor to `nano` with executing `sudo update-alternatives --config editor` and chosing it from the list.

## client-nfs-mount

Usage: `not needed`

Description: init script for mounting individual content