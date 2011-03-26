#!/bin/bash

touch /etc/init.d/fw-script.sh

echo '
#!/bin/sh
 
PATH=/usr/sbin:/sbin:/bin:/usr/bin
 
# Slette all regler
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
 
# Portforwarding
# iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to <ip_adresse:port>
# iptables -A INPUT -p tcp -m state --state NEW --dport 80 -i eth0 -j ACCEPT
 
# Pakkeforwarding
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -j ACCEPT
iptables -A FORWARD -i eth2 -j ACCEPT
 
# Alltid akseptere loopback
iptables -A INPUT -i lo -j ACCEPT
 
# Sørge for pakkeforwarding
echo "1" > /proc/sys/net/ipv4/ip_forward' >> /etc/init.d/fw-script.sh

update-rc.d fw-script.sh defaults
