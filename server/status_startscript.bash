#!/bin/bash

# Start node required
lo=$1

# End node required
hi=$2

# If $3 is set to resume this script will start the simulation on all nodes in range. You can use this for unblocking your R-scripts.
resume=false

if [[ ! -z $3 && "$3" == "resume" ]]; then
	resume=true
fi

if [[ "$resume" == true ]]; then
	echo "resume"
fi

# A assoc. array with hostnames as keys and ips as value
declare -A nodes

declare -A ip_list
low_node=1
high_node=60


function gen_ip_list {
	for (( i=$1;i<=$2;i++ )); do
		local hostname=$(get_hostname $i)
		local ip=$(get_ip $i)
		ip_list[$hostname]=$ip
	done
}



# $1 is geographical position
function get_ip {
	
	ip_pattern_r3="10.42.0."
	ip_pattern_zero="192.168.1."
	
	zero_offset=104
	
	if [[ $i -gt 16 && $i -lt 23 || $i -gt 23 && $i -lt 30 ]]; then
		# Zero
		local last_octet=$(( $i + $zero_offset ))
		echo "$ip_pattern_zero$last_octet"
	else
		# R3
		echo $ip_pattern_r3$i
	fi
}

function get_hostname {
	local nodestr="node"
	if [ "$1" -lt 10 ]; then
		nodestr=""$nodestr"0"
	fi
	nodestr="$nodestr$1"
	echo $nodestr
}

# Validates a range of nodes provided by the user adds it into RANGE. The nodes are only added when they are also in the mac node table provided by MAC_FILE. 
function range_check {
	
	if [[ ! -z $1 && $1 =~ $DIGIT && $1 -gt 0 ]]; then
		lo=$1
	else
		lo=$low_node
	fi	
	
	if [[ ! -z $2 && $2 =~ $DIGIT && $2 -lt 61 ]]; then
		hi=$2
	else
		hi=$high_node
	fi
	
	for (( i=$lo;i<=$hi;i++ )); do
		# Create the directory string
		local hostname=$(get_hostname $i)
		local ip=${ip_list[$hostname]}
		nodes[$hostname]=$ip
	done
	
	

}



gen_ip_list $low_node $high_node

range_check $1 $2

for K in "${!nodes[@]}"; do echo "$K ${nodes[$K]}"; done | sort -n
# for K in "${!ip_list[@]}"; do echo "$K ${ip_list[$K]}"; done | sort -n
