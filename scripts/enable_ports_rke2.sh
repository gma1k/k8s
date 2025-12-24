#!/bin/bash

# TCP ports
ALLOWED_PORTS=(6443 9100 8080 4245 9345 6443 6444 10250 10259 10257 2379 2380 9796 19090 9090 6942 9091 4244 4240 80 443 9963 9964 8081 8082 7000 9001 6379 9121 8084 6060 6061 6062 9879 9890 9891 9892 9893 9962 9966)
for port in "${ALLOWED_PORTS[@]}"; do
	sudo firewall-cmd --add-port="$port/tcp" --permanent
done

# UDP ports (for GENEVE overlay)
UDP_PORTS=(8472 4789 6081 51871 53 55355 58467 41637 39291 38519 46190)
for port in "${UDP_PORTS[@]}"; do
	sudo firewall-cmd --add-port="$port/udp" --permanent
done

# Reload the firewall rules
sudo firewall-cmd --reload
