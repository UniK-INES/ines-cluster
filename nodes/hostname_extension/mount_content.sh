#!/bin/bash

# This script is run on every single pxe clients and mounts individual content
#
# 1) Get your own mac address
# 2) Read in the mac table
# 3) Look up your own directory
# 4) Mount it
#
# Dependencies: file MAC_FILE

read MAC </sys/class/net/eth0/address
CONTENT_DIR="/pxe/nodes/" # trailing / important
MOUNT_DIR="/opt/individual_content"
MAC_FILE="/opt/meta/mac_nodes"
declare -A NODE_LIST

function main {

	read_mac_table

	case "$1" in
		start)
		
			lookup_node
			
			if [ "$?" != 0 ]; then
				echo "It was not possible to find the node in MAC file at $MAC_FILE"
				exit 1
			fi
			

			
			# CONTENT_DIR="BADTEST3"
			
			# Additional tests: last two symbols are digits f.e. node02
			local digits_regex='^[0-9]+$'
			local last_digits=${CONTENT_DIR: -2}
			if [[ ! "$last_digits" =~ $digit ]]; then
				echo "CONTENT_DIR $CONTENT_DIR was not set properly."
				exit 1
			fi
			
			# if sudo mount -t nfs -o soft 10.42.0.250:"$CONTENT_DIR" "$MOUNT_DIR"; then
			if sudo mount -t nfs -o hard,vers=3 10.42.0.250:"$CONTENT_DIR" "$MOUNT_DIR"; then
				echo "$CONTENT_DIR successfully mounted"
			fi
			sudo chown pi:pi "$MOUNT_DIR" -R
			;;
		stop)
			if sudo umount "$MOUNT_DIR"; then
				echo "$MOUNT_DIR successfully unmounted"
			fi
			;;
		*)
			echo "Usage: $0 {start|stop}" >&2
			exit 1
			;;
	esac
	
}

# Returns a valid directory for one single node
function lookup_node {
	
	status=1
	
	# echo "$0"

	if [ -z "$MAC" ]; then
		echo "There was no mac address provided in the lookup function"
		exit 1
	fi
	
	
	
	for id in ${!NODE_LIST[@]}; do
		# echo "i compare with ${NODE_LIST[$id]}"
		if [ "${NODE_LIST[$id]}" = "$MAC" ]; then
			
			# Create the directory string
			local nodestr="node"
			if [ "$id" -lt 10 ]; then
				nodestr=""$nodestr"0"
			fi
			nodestr="$nodestr$id"
			
			CONTENT_DIR="$CONTENT_DIR$nodestr"
					
			return 0
					
		fi
	done
	
	return "$status"

}



# Reads in all valid nodes defined in MAC_FILE
function read_mac_table {
	local MAC_REGEX="([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}"
	while read node_id node_mac || [ -n "$node_mac" ]; do
		if [[ "$node_mac" =~ $MAC_REGEX ]]; then
			NODE_LIST[$node_id]="$node_mac"
			
			# Find minimum and maximum node
			# (( "$node_id" > "$MAX_NODE" )) && MAX_NODE=$node_id
			# (( "$node_id" < "$MIN_NODE" )) && MIN_NODE=$node_id
			
			# Add all valid nodes to default range
			# RANGE_GEN+=($node_id)
		fi
	done < "$MAC_FILE"
}

main "$@"; exit
