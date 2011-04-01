#!/bin/bash

##
# Kun et start dokument. Må utvides MYE!
##

# Banen til iptalbes
IPT="/sbin/iptables"

# WAN data
EKST_IFACE="eth0"
EKST_IP="158.38.56.89"
EKST_CIDR="158.38.56.0/24"

# LAN data
INT_IFACE="eth1"
INT_IP="192.168.145.1"
INT_IP="192.168.145.0/24"

# locahost data
LO_IFACE="lo"
LO_IP="127.0.0.1"

echo "Rensker opp i iptables"
# Reset Default Policies
$IPT -P INPUT ACCEPT
$IPT -P FORWARD ACCEPT
$IPT -P OUTPUT ACCEPT
$IPT -t nat -P PREROUTING ACCEPT
$IPT -t nat -P POSTROUTING ACCEPT
$IPT -t nat -P OUTPUT ACCEPT
$IPT -t mangle -P PREROUTING ACCEPT
$IPT -t mangle -P OUTPUT ACCEPT

# Flush all rules
$IPT -F
$IPT -t nat -F
$IPT -t mangle -F

# Erase all non-default chains
$IPT -X
$IPT -t nat -X
$IPT -t mangle -X

echo "Åpner porter som skal benyttes"
##
# Åpne porter til tjenester. 
##
# Apache
# $IPT -A INPUT -p tcp --dport 80 -j ACCEPT  # http
# $IPT -A INPUT -p tcp --dport 443 -j ACCEPT  # https

# Epost
# $IPT -A INPUT -p tcp --dport 25 -j ACCEPT   # smtp
# $IPT -A INPUT -p tcp --dport 465 -j ACCEPT  # smtp-ssl
# $IPT -A INPUT -p tcp --dport 110 -j ACCEPT  # pop3
# $IPT -A INPUT -p tcp --dport 143 -j ACCEPT  # imap
# $IPT -A INPUT -p tcp --dport 993 -j ACCEPT  # imap-ssl
# $IPT -A INPUT -p tcp --dport 995 -j ACCEPT  # pop3-ssl

# DNS
# $IPT -A INPUT -p tcp --dport 53 -j ACCEPT   # DNS over tcp
# $IPT -A INPUT -p tcp --dport 53 -j ACCEPT   # DNS over udp

# Mysql
# $IPT -A INPUT -p tcp --dport 3306 -j ACCEPT   # Mysql

# SSH
# $IPT -A INPUT -p tcp --dport 22 -j ACCEPT   # ssh

# Flytt alle tcp pakker på port 80 til eth1 på port 3128 (Squid)
$IPT -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to 192.168.145.1:3128

# $IPT -A INPUT -p tcp -m state --state NEW --dport 80 -i eth0 -j ACCEPT

# Pakkeforwarding
$IPT -t nat -A POSTROUTING -o $EKST_IFACE -j MASQUERADE
$IPT -A FORWARD -i $INT_IFACE -j ACCEPT

# Alltid akseptere loopback
$IPT -A INPUT -i $LO_IFACE -j ACCEPT

# Blokker alt på det eksterne interfacet som ikke er åpnet over.
$IPT -A INPUT -i $EKST_IFACE -j DROP

# Sørge for pakkeforwarding
echo "1" > /proc/sys/net/ipv4/ip_forward

echo "Skript kjørt"
