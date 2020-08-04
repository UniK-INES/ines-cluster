#!/bin/bash

# DNSMASQ CONFIG FILE
DHCP_CFG="/etc/dnsmasq.conf"

PXE_BOOT_DIR=""
PXE_ROOT_DIR=""

# Gets the PXE boot directory from dhcp server config. Returns 0 if the directory exists.
function get_pxe_boot_dir {
	
	local grep_regex='^tftp-root='
	local sed_regex='/^tftp-root=/s///p'

	# Counts how many times tftp-root directory was set. Only once should be allowed.
	count=$(grep -o "$grep_regex" "$DHCP_CFG" | wc -l)
	if [ "$count" != 1 ]; then
		return 1
	fi

	# Gets boot directory from dhcp cfg and validates it
	PXE_BOOT_DIR=$(sed -n "$sed_regex" "$DHCP_CFG")
	if [ ! -d "$PXE_BOOT_DIR" ]; then
		return 2
	fi
	
	return 0
}

function get_pxe_root_dir {
	local sed_regex='s/.* nfsroot=10.42.0.250:\(.*\),.*/\1/'
	PXE_ROOT_DIR=$(sed "$sed_regex" "$PXE_BOOT_DIR/cmdline.txt")
	if [ ! -d "$PXE_ROOT_DIR" ]; then
		return 1
	fi
	return 0
}

get_pxe_boot_dir
if [ "$?" != 0 ]; then
	case "$?" in
				"1")
					echo "TFTP root in $DHCP_CFG was not set or was set multiple times."
					exit 1
					;;
					
				"2")
					echo "PXE boot directory $PXE_BOOT_DIR does not exist."
					exit 1
					;;
	esac
fi

get_pxe_root_dir
if [ "$?" != 0 ]; then
	[[ $PXE_ROOT_DIR = "" ]] && status="NULL" || status="$PXE_ROOT_DIR"
	echo "PXE root directory $status does not exist. Check $PXE_BOOT_DIR/cmdline.txt."
fi


exit




# directories (important: relative to /pxe/meta where this script is located)
BOOTDIR="../boot_raspbian/"
NODE_DIR="../nodes/" # individual content for every node is saved here

# files
DHCP_FILE="../../etc/dnsmasq.d/mac_table" # dhcp config is saved here
MAC_FILE="data/mac_nodes" # lookup table. important \n as line ending is expected. \r\n (windows) will break the script

# patterns
HOSTNAME_PATTERN="node" # decimal number of host is later appended
IP_PATTERN="10.42.0." 

if [ ! -f $MAC_FILE ]; then
	echo "Can't find MAC Table at $MAC_FILE"
	exit 123
else
	cat $MAC_FILE
fi


if [ -f $DHCP_FILE ]; then
	sudo rm $DHCP_FILE
	printf "DHCP Lookup Table exists. Removing it. \n"
fi

sudo touch $DHCP_FILE

declare -A MAC_TABLE

NODE_ARRAY=()


# reads in mac table. format decimal (geographical place of module) = hardware address
function createMacTable {
	local MAC_REGEX="([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}"
	local amount=0
	
	while read node_id node_mac || [ -n "$node_mac" ]; do
		if [[ "$node_mac" =~ $MAC_REGEX ]]; then
			printf "Creating Node directory dec:%s mac:%s\n" $node_id $node_mac
			MAC_TABLE[$node_id]="$node_mac"
			((amount++))
		fi
		
	done < "$MAC_FILE"
	echo "Found $amount valid nodes"
}

createMacTable

# create the dhcp config file. n dezimal identifier for the node
for node_id in "${!MAC_TABLE[@]}"; do

	str=$(printf "dhcp-host=%s,%s%s,%s%s,infinite" "${MAC_TABLE[$node_id]}" "$HOSTNAME_PATTERN" "$node_id" "$IP_PATTERN" "$node_id")
	echo -e "${str}"
	# str="dhcp-host=${MAC_TABLE[$dec_id]},${HOSTNAME_PATTERN}$dec_id,10.42.0.$dec_id,infinite\n";
	#echo $str;
	#echo $str | sudo tee -a $DHCP_FILE;
done

counter=0
while read node_id node_mac || [ -n "$node_mac" ]; do
        if [[ "$node_mac" =~ $MAC_REGEX ]]; then
                #valid mac
                fullpath="${NODE_DIR}$node_mac"
                if [[ ! -d $fullpath ]]; then
                        # printf "Creating directory for node %s at %s\n" $node_id $fullpath
                        mkdir -p "$fullpath"
                        if [ $? -ne 0 ]; then
                                printf "Something went wrong with node %s\n" $node_id
                        fi
                else
                        printf "Directory exists for node %s\n" $node_id >> /dev/null
                fi

                NODE_ARRAY+=($node_mac)
                ((counter++))

        else
                #invalid mac
                printf "Invalid MAC: %s" $node_mac
        fi

        #[[ "$node_mac" =~ $regex ]] && echo "valid" || echo "invalid"
        #[[ "$node_mac" =~ "[[:space:]]+" ]] && echo "whitespace" || echo "no whitespace"
        # echo $fullpath


done < $MAC_FILE

# for i in ${NODE_ARRAY[@]}; do
#       printf "%s\n" $i
# done
# printf "%s" $counter


if [ ! -d "$BOOTDIR" ]; then
	# boot dir does not exist
	mkdir "$BOOTDIR"
	if [ $? -eq 0 ]; then
		echo "Created Boot partition at $BOOTDIR"
	else
		echo "Couldn't create $BOOTDIR"
		exit 1
	fi
fi

# create the ssh file to enable the ssh server
touch "${BOOTDIR}ssh"
if [ $? -eq 0 ]; then
	echo "Created ssh file at $BOOTDIR"
fi