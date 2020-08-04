import argparse
import sys
from websocket import create_connection

# Default IP for the server node
serverNode="192.168.1.111"

parser = argparse.ArgumentParser(description='Can restart a node identified by geographical position')
parser.add_argument('-s', action="store", dest="serverNode", default="", help="ip address of the server node")
parser.add_argument('-n', dest="node", default=0, type=int, help="id of the node you want to restart")
parser.add_argument('-a', choices=["off", "on"], dest="state", default="off", help="on|off")
args = parser.parse_args()


if not 1 <= args.node <= 60:
	print("Node not in range")
	sys.exit(1)

if args.serverNode != "":
	serverNode = args.serverNode

# Connection
host="ws://" + serverNode + ":1236/"
ws = create_connection(host)	
	
def Issue(message):
	ws.send(message)
	exit(0)
	
if args.state == "off":
	Issue('{"target":"bladerunner","seqno":1,"command":"XPowerRequest","args":{"id":' + str(args.node) + ',"on":false}}')
else:
	Issue('{"target":"bladerunner","seqno":1,"command":"XPowerRequest","args":{"id":' + str(args.node) + ',"on":true}}')


	



