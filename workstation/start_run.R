require('ssh')
require('readr')

start_run <- function(pid) {
	pid <- parse_number(pid)
	print(pid)
	Sys.sleep(5)
	ssh_exec_wait(session, command = paste('BDEBUG=true /pxe/meta/sim_start_on_nodes start', node, pid, sep=" "))
}

session <- ssh_connect("outsider@141.51.123.55")
node <- 2

ssh_exec_wait(session, command = paste('/pxe/meta/sim_start_on_nodes init ', node, sep=""), std_out = function(x) { start_run(rawToChar(x))})

