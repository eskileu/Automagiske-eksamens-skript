#!/bin/bash

##
# Kun et start dokument. Må utvides MYE!
##

PATH=/usr/sbin:/sbin:/bin:/usr/bin

echo "Skript kjørt"
# Slette all regler
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Lukk en del porter for den eksterne verdenen
iptables -A INPUT -i eth0 -p tcp -m tcp --dport 138 -j DROP
iptables -A INPUT -i eth0 -p tcp -m tcp --dport 389 -j DROP
iptables -A INPUT -i eth0 -p tcp -m tcp --dport 445 -j DROP
iptables -A INPUT -i eth0 -p udp -m udp --dport 137 -j DROP
iptables -A INPUT -i eth0 -p tcp -m tcp --dport 139 -j DROP
# Squid the shit out of it.
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to 192.168.145.1:3128

# iptables -A INPUT -p tcp -m state --state NEW --dport 80 -i eth0 -j ACCEPT

# Pakkeforwarding
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -j ACCEPT

# Alltid akseptere loopback
iptables -A INPUT -i lo -j ACCEPT

# Sørge for pakkeforwarding
echo "1" > /proc/sys/net/ipv4/ip_forward

