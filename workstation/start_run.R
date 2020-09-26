require('ssh')
require('readr')

start_run <- function(cbstream) {
	rpid <- rawToChar(cbstream)
	pid <- parse_number(rpid)
	Sys.sleep(5)
	ssh_exec_wait(session, command = paste('BDEBUG=true /pxe/meta/sim_start_on_nodes start 2', pid, sep=" "))
}

session <- ssh_connect("outsider@141.51.123.55")

ssh_exec_wait(session, command = '/pxe/meta/sim_start_on_nodes init 2', std_out = function(x) { start_run(x)})

