require('snowfall')

sfInit(parallel=TRUE, cpus=4, type="SOCK", slaveOutfile="./slave_out.txt")
#sfInit(parallel=FALSE)
sfLibrary(ssh)
sfLibrary(readr)

# Full path to your simulation directory
sim_path <- "/home/chh/ines-cluster/workstation/R/testsim"
# Name of the simulation
sim_name <- basename(sim_path)
# Executable in simulation directory. Something like "java .." is possible too.
sim_cmd <- "cmd"

# Range of nodes that should run the simulation
lo=8
hi=9
span <- if (lo > hi) 1 else hi - lo + 1

############### Internals ###############

# Ssh connection

ssh_con <- function() {
  session <- ssh_connect("outsider@141.51.123.55") 
  return(session) 
}
session <- ssh_con()

# Simulation directory on server node
pxe <- "/pxe/meta/simulation/"

# Init/Exec script on server node
sim_ctrl <- "/pxe/meta/sim_start_on_nodes"

# Distribution script on server node
sim_dist <- "/pxe/meta/sim_to_nodes"

# Local simulation files
sim_files <- dir(sim_path)

# Retrieves the PID of the simulation process started on nodes
retrieve_pid <- function(cbstream, node) {
  rpid <- rawToChar(cbstream)
  pid <- parse_number(rpid)
  Sys.sleep(2)
  pid_list[[get_node(node)]][3] <<- pid
  print(paste("Retrieved PID for node ", node, ": ", pid, sep=""))
  start_sim(node, pid)
  # return(pid)
}

start <- function() {
  upload_sim(sim_files)
  
  for (geo_pos in lo:hi) {
    # assign("current_node", node, envir = .GlobalEnv)
	session <- ssh_connect("outsider@141.51.123.55") 
    ssh_exec_wait(session, command = paste(sim_ctrl, 'init', geo_pos, sep=" "), std_out = function(x) { retrieve_pid(x, geo_pos)})
	ssh_disconnect(session)
  }
}

# Starts the simulation
start_sim <- function(node, pid) {
  print(paste("Starting on ", node, " (PID: ", pid,")", sep=""))
  session <- ssh_connect("outsider@141.51.123.55") 
  ssh_exec_wait(session, command = paste(sim_ctrl, 'start', node, pid, sep=" "))
  ssh_disconnect(session)
}

# Uploads simulation files to nodes
upload_sim <- function(files) {
  
  # Create simulation directory on server node
  out <- ssh_exec_wait(session, command = paste('mkdir', paste(pxe, sim_name, sep="/"), sep=" "))
  
  # Upload the simulation to the server node
  for (f in files) {
    out <- scp_upload(session, paste(sim_path, f, sep="/"), paste(pxe, sim_name, sep="/")) 
  }
  
  # Distribute to nodes
  for (node in lo:hi) {
    out <- ssh_exec_wait(session, command = paste(sim_dist, sim_name, node, sep=" "))
  }	
}

# Generates the list used for storing pid of simulation on node
prepare_pid_list <- function(lo, hi, span) {

  pid_list <- vector(mode = "list", length = span)
  
  geo_pos <- lo
  for (i in 1:span) {
    spacer <- if (geo_pos < 10) "0" else ""
    hostname <- paste("node", spacer, geo_pos, sep="")
    pid_list[[i]] <- c(geo_pos, hostname, -1)
    geo_pos <- geo_pos + 1
  }
  
  return(pid_list)
  
}

# Returns pid_list index for node with geographical position
get_node <- function(geo_pos) {
  result <- -1
  i <- 1
  for (node in pid_list)
    if (node[1] == geo_pos) {
      result <- i
      break
    } else i <- i + 1
      
  return(result)
}

# Takes geographical position (1-60) of a node and initializes the simulation
init_node <- function(geo_pos) {
  print(paste("Starting init_node on Geo-Pos", geo_pos))
  # session <- ssh_con()
  
  # The node we work with
  node <- get_node(geo_pos)
  
  # Node with geographical position was not found in pid_list
  if (node != -1) {
    #assign("current_node", pid_list[[node]][1], envir = .GlobalEnv)
	session <- ssh_connect("outsider@141.51.123.55") 
    ssh_exec_wait(session, command = paste(sim_ctrl, 'init', geo_pos, sep=" "), std_out = function(x) { retrieve_pid(x, geo_pos)})
	ssh_disconnect(session)
  }   
  return(pid_list[[node]])
}


pid_list <- prepare_pid_list(lo, hi, span)

upload_sim(sim_files)

sfExport("pid_list", "get_node", "start_sim", "retrieve_pid", "sim_ctrl")

#update_pid_list(sfLapply(as.list(sapply(pid_list,'[[',1)), init_node))
pid_list <- sfLapply(as.list(sapply(pid_list,'[[',1)), init_node)

# print(result)



for (node in pid_list) {
  print(node)
}

# start()

sfStop()
Sys.sleep(10)
ssh_disconnect(session)