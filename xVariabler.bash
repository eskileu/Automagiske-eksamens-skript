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


# ---------
# VARIABLER
# ---------
# Hardkodingen vil da sørge for at variabler 
# ikke fylles inn med data fra feks ifconfig
#


# ---WAN--- #
WAN_IP=""   # OBS! Om WAN_IP hardkodes må også W_IP1 W_IP2... hardkodes
WAN_MASKE=""
WAN_CIDR=""
WAN_REV=""

# ---LAN--- #
LAN_IP=""   # OBS! Om LAN_IP hardkodes må også L_IP1 L_IP2... hardkodes
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
W_IP1=""
W_IP2=""
W_IP3=""
W_IP4=""
L_IP1=""
L_IP2=""
L_IP3=""
L_IP4=""


echo -n 'Hvilket interface er ditt eksterne| WAN (eth0,eth1,wlan0...): '
read WAN_IFACE

echo -n 'Hvilket interface er ditt interne | LAN (eth0,eth1,wlan0...): '
read LAN_IFACE



# ---HENT--- #
# Henter kun om variabler ikke er hardkodet
if [ -z $WAN_IP ]; then
    WAN_IP=`ifconfig $WAN_IFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
    W_IP1=`echo $WAN_IP | cut -d. -f1`
    W_IP2=`echo $WAN_IP | cut -d. -f2`
    W_IP3=`echo $WAN_IP | cut -d. -f3`
    W_IP4=`echo $WAN_IP | cut -d. -f4`
fi

if [ -z $WAN_MASKE ]; then
    WAN_MASKE=`ifconfig eth0 | grep 'Mask:' | cut -d: -f4 | awk '{ print $1}'`
fi

if [ -z $WAN_CIDR ]; then
    ANTBIT="/"$(mask2cidr $WAN_MASKE) # mas2cidr --> xFunksjoner.bash
    WAN_CIDR=$W_IP1"."$W_IP2"."$W_IP3".0"$ANTBIT
fi

if [ -z $WAN_REV ]; then
    WAN_REV=$W_IP3.$W_IP2.$W_IP1 # Revers for dns
fi






