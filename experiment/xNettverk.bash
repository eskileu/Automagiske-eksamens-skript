#!/bin/bash 
. xVariabler.bash
. xMake2CIDR.bash
. xColor.bash

## 
# Eksperimentel kode som kanskje har en fremtid.
# En del av experiment branchen til automagiske
# skript til eksamen. Skilt ut for at de
# ikke skal kludre til master branch. Merges inn
# i master når ting er testet godt nok
##


# ---------
# VARIABLER
# ---------
# Hardkodingen vil da sørge for at variabler 
# ikke fylles inn med data fra feks ifconfig
#

echo -n 'Hvilket interface er ditt eksterne| WAN (eth0,eth1,wlan0...): '
read WAN_IFACE

echo -n 'Hvilket interface er ditt interne | LAN (eth0,eth1,wlan0...): '
read LAN_IFACE



# ---HENT--- #
# Henter kun om variabler ikke er hardkodet

# START WAN
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
# SLUTT WAN

# START LAN
if [ -z $LAN_IP ]; then
    LAN_IP=`ifconfig $LAN_IFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
    L_IP1=`echo $LAN_IP | cut -d. -f1`
    L_IP2=`echo $LAN_IP | cut -d. -f2`
    L_IP3=`echo $LAN_IP | cut -d. -f3`
    L_IP4=`echo $LAN_IP | cut -d. -f4`
fi

if [ -z $LAN_MASKE ]; then
    LAN_MASKE=`ifconfig eth0 | grep 'Mask:' | cut -d: -f4 | awk '{ print $1}'`
fi

if [ -z $LAN_CIDR ]; then
    ANTBIT="/"$(mask2cidr $LAN_MASKE) # mas2cidr --> xFunksjoner.bash
    LAN_CIDR=$L_IP1"."$L_IP2"."$L_IP3".0"$ANTBIT
fi

if [ -z $LAN_REV ]; then
    LAN_REV=$L_IP3.$L_IP2.$L_IP1 # Revers for dns
fi # SLUTT LAN

echo "
######################
 NETVERKS INFORMASJON
######################
Dataen er prøvd hentet ut mest mulig uten bruker input.
Om nettverksinformasjonen ikke skulle stemme noter ned
hvilken informasjon som ikke var korrekt og rapporter
det til utvikler. Sørg for å dobbelsjekke at de aktuelle 
interface var oppe og at du skrev inn riktig navn på de.
Data hentet fra: /tmp/$TMPFIL 

${txtgrn}${txtbld}*---HOST---*${txtrst}
Maskinnavn              $MASKINNAVN
Domene                  $DOMENE

${txtblu}${txtbld}*---WAN---*${txtrst}
IP                      $WAN_IP
Nettmaske               $WAN_MASKE
CIDR                    $WAN_CIDR
Nettverk                $W_IP1.$W_IP2.$W_IP3.0
Rev IP                  $WAN_REV

${txtred}${txtbld}*---LAN---*${txtrst}
IP                      $LAN_IP
Nettmaske               $LAN_MASKE
CIDR                    $LAN_CIDR
Nettverk                $L_IP1.$L_IP2.$L_IP3.0
Rev IP                  $LAN_REV
" > /tmp/$TMPFIL

cat /tmp/$TMPFIL





