#!/usr/bin/env bash

# Get the local IP address
local_ip=$(hostname -I | awk '{print $1}')

/usr/bin/socat tcp-listen:5554,bind=${local_ip},fork tcp:127.0.0.1:5554
/usr/bin/socat tcp-listen:5555,bind=${local_ip},fork tcp:127.0.0.1:5555
