#!/bin/bash 

## 
# Automatisert openvpn nøkkel generering for klienter
# Rev. 0.1 (1.0 er det samme som fult operativ)
# -------------
# 0.1 skjellet på plass, ikke testet
#
# TODO:
#
##


#################################################
# UNDER DETTE SKILLET SKAL KUN FUNKSJONER LIGGE 
# FUNKSJONER MÅ VIST LESES FØRST...             
#################################################

# Rydde funksjon. Kun et skjelett må fylles
function cleanUp()
{
	echo "RYDDER OPP ETTER DEG!!"
	# LEGG INN KODE
}

# Pause funksjon som krever [ENTER] for å fortsette
function pause(){
	read -p "$*"
}

# Funksjon for kontroll av input.
function getInput()
{
	if (( $1 == 1 )); then		## THIS MEANS ANY INPUT IS FINE !
		VERIFY_INPUT=0
	elif (( $1 == 2 )); then	## THIS MEANS YES/NO CONFIRMATION
		VERIFY_INPUT=1
	else
		VERIFY_INPUT=2		## SELECTIVE INPUT
	fi

	loop=0
	while (($loop != 1)); do

		echo -n "< $SPORSMAL"
		INPUT=""
		read INPUT

		# make a copy of the input in lower case
		INPUT_LOWER_CASE=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')

		# *always* exit if we get 'q'
		if [ "$INPUT_LOWER_CASE" == "q" ]; then
			cleanUp
			exit
		fi

		# we don't want input that's empty unless it's for mode 1
		if (( $VERIFY_INPUT != 0 )) && (( ${#INPUT} == 0 )); then
			continue
		fi

		# if we're in mode 1 (verify == 0) we basicly just accept any input. 
		# in this case we set loop=1 so the while exits
		if (( $VERIFY_INPUT == 0 )); then
			loop=1
		elif (( $VERIFY_INPUT == 1 )); then
			if [ "$INPUT_LOWER_CASE" == "y" ] || [ "$INPUT_LOWER_CASE" == "n" ]; then
				loop=1
			fi
		else
			## remember; $1 is input option, start at 2nd argument
			for ((x=2; x!=$(($#+1)); x++)); do

				if [ "$INPUT" == "${@:$x:1}" ]; then
					loop=1
				fi
			done
		fi
	done
}

##################################################
# UNDER DETTE SKILLET KJØRER VI NOEN ENKLE TESTER
##################################################

TEMP=$1 # Forbanna $1 funket dårlig direkte i if setningen....
# Kommenter ut når rev er testet. 
if [ "$TEMP" != "test" ]; then
	echo "Det jobbes med scriptet for øyeblikket vennligst prøv igjen senere"
	exit
fi

# Test for å sikre at kun root kan kjøre skriptet.
if (( $UID != 0 )); then
	echo "*!* FATAL: Can only be executed by root."
	exit
fi

# Vi er avhengig av nett til installasjonene så vi gjør en pingtest
if ping -c 1 158.38.48.10 > /dev/null; then
	echo "PING: OK"
else
	REDTEMP=$(tput setaf 1)
	RESETTEMP=$(tput sgr0)
	echo "PING: ${REDTEMP}FAILED${RESETTEMP}"
	echo "Skript avsluttet siden vi ikke har nett"
	exit
fi

# Verifiser at brukeren virkelig vil gå videre
pause "Om du er sikker trykk ENTER eller avbryt med CTRL+C"

##################
# Action part :) 
##################

# Vi henter variabel input fra brukeren
KLIENT=""
BRUKER=""
VPN_SERVER=""

SPORSMAL="Skriv inn navnet på klientnøkkel (default er CLIENT):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	KLIENT="CLIENT"
else
	KLIENT=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn navnet på brukeren (default er PER):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	BRUKER="PER"
else
	BRUKER=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn ip/FDQN på vpn-server (default er ip.addr på eth0):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	VPN_SERVER=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`
else
	VPN_SERVER=$INPUT_LOWER_CASE
fi

# Oppretter mappe for nøklene
mkdir -p /home/$BRUKER/.openvpn

# Oppretter nøklene
cd /etc/openvpn/easy-rsa

source /etc/openvpn/easy-rsa/vars

/etc/openvpn/easy-rsa/pkitool $KLIENT

cp /etc/openvpn/easy-rsa/keys/$KLIENT* /home/$BRUKER/.openvpn

# Oppretter klient config fil
touch /home/$BRUKER/.openvpn/client.conf

echo "
##############################################
# Sample client-side OpenVPN 2.0 config file #
# for connecting to multi-client server.     #
#                                            #
# This configuration can be used by multiple #
# clients, however each client should have   #
# its own cert and key files.                #
#                                            #
# On Windows, you might want to rename this  #
# file so it has a .ovpn extension           #
##############################################

# Specify that we are a client and that we
# will be pulling certain config file directives
# from the server.
client

# Use the same setting as you are using on
# the server.
# On most systems, the VPN will not function
# unless you partially or fully disable
# the firewall for the TUN/TAP interface.
;dev tap
dev tun

# Windows needs the TAP-Win32 adapter name
# from the Network Connections panel
# if you have more than one.  On XP SP2,
# you may need to disable the firewall
# for the TAP adapter.
;dev-node MyTap

# Are we connecting to a TCP or
# UDP server?  Use the same setting as
# on the server.
;proto tcp
proto udp

# The hostname/IP and port of the server.
# You can have multiple remote entries
# to load balance between the servers.
remote $VPN_SERVER 1194
;remote my-server-2 1194

# Choose a random host from the remote
# list for load-balancing.  Otherwise
# try hosts in the order specified.
;remote-random

# Keep trying indefinitely to resolve the
# host name of the OpenVPN server.  Very useful
# on machines which are not permanently connected
# to the internet such as laptops.
resolv-retry infinite

# Most clients don't need to bind to
# a specific local port number.
nobind

# Downgrade privileges after initialization (non-Windows only)
;user nobody
;group nobody

# Try to preserve some state across restarts.
persist-key
persist-tun

# If you are connecting through an
# HTTP proxy to reach the actual OpenVPN
# server, put the proxy server/IP and
# port number here.  See the man page
# if your proxy server requires
# authentication.
;http-proxy-retry # retry on connection failures
;http-proxy [proxy server] [proxy port #]

# Wireless networks often produce a lot
# of duplicate packets.  Set this flag
# to silence duplicate packet warnings.
;mute-replay-warnings

# SSL/TLS parms.
# See the server config file for more
# description.  It's best to use
# a separate .crt/.key file pair
# for each client.  A single ca
# file can be used for all clients.
ca /home/$BRUKER/.openvpn/ca.crt
cert /home/$BRUKER/.openvpn/$KLIENT.crt
key /home/$BRUKER/.openvpn/$KLIENT.key

# Verify server certificate by checking
# that the certicate has the nsCertType
# field set to server.  This is an
# important precaution to protect against
# a potential attack discussed here:
#  http://openvpn.net/howto.html#mitm
#
# To use this feature, you will need to generate
# your server certificates with the nsCertType
# field set to server.  The build-key-server
# script in the easy-rsa folder will do this.
ns-cert-type server

# If a tls-auth key is used on the server
# then every client must also have the key.
;tls-auth ta.key 1

# Select a cryptographic cipher.
# If the cipher option is used on the server
# then you must also specify it here.
;cipher x

# Enable compression on the VPN link.
# Don't enable this unless it is also
# enabled in the server config file.
comp-lzo

# Set log file verbosity.
verb 3

# Silence repeating messages
;mute 20" >> /home/$BRUKER/.openvpn/client.conf

# Sette rettighetene til brukeren på filene vi har laget
chown $BRUKER:`id -gn $BRUKER` /home/$BRUKER/.openvpn/*

echo "Alle filer ligger i brukerens hjemmekatalog i mappen .openvpn"

