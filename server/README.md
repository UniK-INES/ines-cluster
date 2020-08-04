# Server module context

These scripts are run on the server module. Some of them support setting a debugging switch for further information. `BDEBUG=true ./scriptname`. Commands on the cluster are run via chain of scripts and return/exit codes are delegated 
to the invoking script. If debug is set on there may be undefined or unexpected behaviour. For more information look into the single debug sections.


## sim_start_on_nodes
Usage: `sim_start_on_nodes init|start node(integer)`

Dependencies (soft): global_functions

Description: This script prepares a node's environment to run a user specified command. If the command is not found on the node a default command is run. First run is usually an init. Second run a start. Further information in client context.

Debug: TODO!

* ssh into node
`ssh nfsuser@10.42.0.2`
...