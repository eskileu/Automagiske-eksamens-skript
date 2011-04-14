#!/bin/bash

##
# VARIABLER
# ---------
# Hardkodingen vil sørge for at variabler 
# ikke fylles inn med data fra feks ifconfig
##


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
EPOST="ole@sau.no"      # TMP HARDKODET
MYSQL_ROOT="l33tw0rd"   # TMP HARDKODET
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
