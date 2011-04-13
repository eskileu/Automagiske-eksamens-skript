#!/bin/bash 
. xFunksjoner.bash
## 
# Eksperimentel kode som kanskje har en fremtid.
# En del av experiment branchen til automagiske
# skript til eksamen. Skilt ut for at de
# ikke skal kludre til master branch. Merges inn
# i master når ting er testet godt nok
# -------------
# 
##

##
# VARIABLER
# ---------
# Hardkodingen vil da sørge for at variabler 
# ikke fylles inn med data fra feks ifconfig
##


# ---WAN--- #
WAN_IP="" #Om denne hardkodes må også IP1 IP2 IP3 osv hardkodes
WAN_MASKE=""
WAN_CIDR=""
WAN_REV=""

# ---LAN--- #
LAN_IP=""
LAN_MASKE=""
LAN_CIDR=""
LAN_REV=""

# ---DIV--- #
DOMENE=`hostname -d`
EPOST="ole@sau.no"
MYSQL_ROOT="l33tw0rd"
MASKINNAVN=`hostname`

# ---TMP---#
TMPFIL=`date +%N`".tmp"
ANTBIT=""
IP1=""
IP2=""
IP3=""
IP4=""


echo -n 'Hvilket interface er ditt eksterne| WAN (eth0,eth1,wlan0...): '
read WAN_IFACE

echo -n 'Hvilket interface er ditt interne | LAN (eth0,eth1,wlan0...): '
read LAN_IFACE

if [ -z $WAN_IP ]; then
    WAN_IP=`ifconfig $WAN_IFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
    IP1=`$WAN_IP | cut -d. -f1`
    IP2=`$WAN_IP | cut -d. -f2`
    IP3=`$WAN_IP | cut -d. -f3`
    IP4=`$WAN_IP | cut -d. -f4`
fi

if [ -z $WAN_MASKE ]; then
    WAN_MASKE=`ifconfig eth0 | grep 'Mask:' | cut -d: -f4 | awk '{ print $1}'`
fi

if [ -z $WAN_CIDR ]; then

    ANTBIT="/"$(mask2cidr $WAN_MASKE)
fi


