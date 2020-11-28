require('snowfall')

sfInit(parallel=TRUE, cpus=4, type="SOCK", slaveOutfile="./slave_out.txt")

# Libraries used in parallel processing
sfLibrary(ssh)
sfLibrary(readr)

# Full path to your simulation directory
sim_path <- "/home/chh/ines-cluster/workstation/R/testsim"

# Name of the simulation. Default is directory name.
sim_name <- basename(sim_path)

# Executable in simulation directory. Careful when command name is the same as a command in $PATH on nodes.
sim_cmd <- "cmd"

# Nodes [start_node; end_node] which will run the simulation
lo=8
hi=9
span <- if (lo > hi) 1 else hi - lo + 1

#########################################
####    Local script context    #########
#########################################

get_ssh_session <- function() {
  session <- ssh_connect("outsider@141.51.123.55") 
  return(session) 
}
session <- get_ssh_session()

# Local simulation files
sim_files <- dir(sim_path)

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

#########################################
####      Local script end      #########
#########################################



#########################################
####    Server module context   #########
#########################################

# Simulation directory on server node
pxe <- "/pxe/meta/simulation/"

# Init/Exec script on server node
sim_ctrl <- "/pxe/meta/sim_start_on_nodes"

# Distribution script on server node
sim_dist <- "/pxe/meta/sim_to_nodes"

# Uploads and distributes simulation on range of nodes
sim_upload <- function(files) {
  
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


# After starter script is initiated it waits for sim_ctrl to resume/start the simulation
sim_start <- function(node, pid) {
  print(paste("Starting on ", node, " (PID: ", pid,")", sep=""))
  session <- get_ssh_session()
  ssh_exec_wait(session, command = paste(sim_ctrl, 'start', node, pid, sep=" "))
  ssh_disconnect(session)
}

start <- function() {
  sim_upload(sim_files)
  
  for (geo_pos in lo:hi) {
    # assign("current_node", node, envir = .GlobalEnv)
    session <- get_ssh_session()
    ssh_exec_wait(session, command = paste(sim_ctrl, 'init', geo_pos, sep=" "), std_out = function(x) { retrieve_pid(x, geo_pos) })
    ssh_disconnect(session)
  }
}

#########################################
####      Server module end     #########
#########################################



#########################################
####     Client node context    #########
#########################################

# Takes geographical position (1-60) of a node and initializes the simulation
init_node <- function(geo_pos) {
  print(paste("Starting init_node on Geo-Pos", geo_pos))
  # session <- ssh_con()
  
  # The node we work with
  node <- get_node(geo_pos)
  
  # Node with geographical position was not found in pid_list
  if (node != -1) {
    #assign("current_node", pid_list[[node]][1], envir = .GlobalEnv)
    session <- get_ssh_session()
    ssh_exec_wait(session, command = paste(sim_ctrl, 'init', geo_pos, sep=" "), std_out = function(x) { retrieve_pid(x, geo_pos)})
    ssh_disconnect(session)
  }   
  return(pid_list[[node]])
}

# Callback function that retrieves the PID of the simulation process on node
retrieve_pid <- function(cbstream, node) {
  rpid <- rawToChar(cbstream)
  pid <- parse_number(rpid)
  Sys.sleep(2)
  pid_list[[get_node(node)]][3] <<- pid
  print(paste("Retrieved PID for node ", node, ": ", pid, sep=""))
  sim_start(node, pid)
  # return(pid)
}

#########################################
####       Client node end      #########
#########################################

#########################################
####    Script execute part     #########
#########################################

# This list contains nodes which will run the simulation
pid_list <- prepare_pid_list(lo, hi, span)

# Upload and distribute simulation files to server node
sim_upload(sim_files)

# Export to parallel processes
sfExport("pid_list", "get_ssh_session", "get_node", "sim_start", "retrieve_pid", "sim_ctrl")

# Init simulation on every node in pid_list
pid_list <- sfLapply(as.list(sapply(pid_list,'[[',1)), init_node)

# print(result)

for (node in pid_list) {
  print(node)
}

#########################################
####     Script execute end     #########
#########################################





#########################################
####    Cleaning / Destruct     #########
#########################################

sfStop()
Sys.sleep(10)
ssh_disconnect(session)