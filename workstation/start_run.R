require('ssh')
require('readr')

start_run <- function(pid) {
	pid <- parse_number(pid)
	print(pid)
	ssh_exec_wait(session, command = paste('/pxe/meta/sim_start_on_nodes start ', node, sep=""))
}

session <- ssh_connect("outsider@141.51.123.55")
node <- 2

ssh_exec_wait(session, command = paste('/pxe/meta/sim_start_on_nodes init ', node, sep=""), std_out = function(x) { start_run(rawToChar(x))})

