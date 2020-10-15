require('ssh')
require('readr')

# Full path to your simulation directory
sim_path <- "/home/chh/ines-cluster/workstation/R/testsim"
# Name of the simulation
sim_name <- basename(sim_path)
# Executable in simulation directory. Something like "java .." is possible too.
sim_cmd <- "cmd"

# Range of nodes that should run the simulation
node_beg <- 8
node_end <- 9

############### Internals ###############

# Ssh connection
session <- ssh_connect("outsider@141.51.123.55")

# Simulation directory on server node
pxe <- "/pxe/meta/simulation/"

# Init/Exec script on server node
sim_ctrl <- "/pxe/meta/sim_start_on_nodes"

# Distribution script on server node
sim_dist <- "/pxe/meta/sim_to_nodes"

# Current node we are working on used in global context
current_node <- node_beg

# Local simulation files
sim_files <- dir(sim_path)

# Retrieves the PID of the simulation process started on nodes
retrieve_pid <- function(cbstream) {
	rpid <- rawToChar(cbstream)
	pid <- parse_number(rpid)
	Sys.sleep(2)
	print(current_node)
	start_sim(current_node, pid)
	# return(pid)
}

start <- function() {
	upload_sim(sim_files)
	
	for (node in node_beg:node_end) {
		current_node <<- node
		# assign("current_node", node, envir = .GlobalEnv)
		ssh_exec_wait(session, command = paste(sim_ctrl, 'init', node, sep=" "), std_out = function(x) { retrieve_pid(x)})
	}
}

# Starts the simulation
start_sim <- function(node, pid) {
	print(paste("Starting on ", node))
	ssh_exec_wait(session, command = paste(sim_ctrl, 'start', node, pid, sep=" "))
}

# Uploads simulation files to nodes
upload_sim <- function(files) {
	
	# Create simulation directory on server node
	out <- ssh_exec_wait(session, command = paste('mkdir', paste(pxe, sim_name, sep="/"), sep=" "))
	
	# Loop through node range and distribute
	for (f in files) {
		out <- scp_upload(session, paste(sim_path, f, sep="/"), paste(pxe, sim_name, sep="/")) 
	}
	
	# Distribute to nodes
	for (node in node_beg:node_end) {
		out <- ssh_exec_wait(session, command = paste(sim_dist, sim_name, node, sep=" "))
	}	
}

# upload_sim(sim_files)

start()

ssh_disconnect(session)

