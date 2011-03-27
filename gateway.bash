#!/bin/bash

#
# Installasjonsscript for sette opp dual homed maskin
# som gateway, med nat'ing og forwarding
#
## Rev. 0.2beta (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# 0.2 Fullført til betatesting
# -------------
# Last edit: Sat 26 Mar 2011
#
# TODO:
# 1. Legge til disabling av ipv6
# 2. Sperre for ipv6 i iptables
##

# Oppretter startup script og legger dette til slilk at det starter opp
# ved boot

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

# Disable ipv6 slik at nettverksinterfacen ikke starter opp med dette

# echo net.ipv6.conf.all.disable_ipv6=1 > /etc/sysctl.d/disableipv6.conf
