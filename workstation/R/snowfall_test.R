require('snowfall')

sfInit(parallel=TRUE, cpus=4, type="SOCK")
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

# Current node we are working on used in global context
current_node <- lo

# Local simulation files
sim_files <- dir(sim_path)

pid_list <- prepare_pid_list(lo, hi, span)

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
  
  for (node in lo:hi) {
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

  # session <- ssh_con()
  
  # The node we work with
  node <- get_node(geo_pos)
  
  # Node with geographical position was not found in pid_list
  if (node != -1) {
    assign("current_node", pid_list[[node]], envir = .GlobalEnv)
    ssh_exec_wait(session, command = paste(sim_ctrl, 'init', node, sep=" "), std_out = function(x) { retrieve_pid(x)})
    pid <- 123
    # pid_list[[node]][[3]] <<- pid
    # assign(pid_list[[node]][[3]], pid, envir = .GlobalEnv)
  } 
  
  return(c(node, pid))

}

# Takes a list of 2-dim vectors (listindex, pid) and updates pid_list
update_pid_list <- function(result) {
  print("Updating pid_list")

  for (node_result in result) {
    i <- node_result[1]
    pid_list[[i]][3] <<- node_result[2]
    print(paste("list index: ", i, " pid: ", node_result[2], sep=""))
  }

}

upload_sim(sim_files)

sfExport("pid_list", "get_node", "session", "start_sim", "retrieve_pid", "sim_ctrl")


update_pid_list(sfLapply(sapply(pid_list,'[[',1), init_node))

# print(result)



for (node in pid_list) {
  print(node)
}

# start()

sfStop()
Sys.sleep(10)
ssh_disconnect(session)