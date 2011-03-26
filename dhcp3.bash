#!/bin/bash

#
# Installasjonsscript for dhcp3
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
# 
##

###############
# Functions             
###############

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

#####################################################
# UNDER DETTE SKILLET KJØRER VI NOEN ENKLE TESTER
# FOR Å SJEKKE AT VI KAN GÅ VIDERE I KONFIGURASJONEN
#####################################################

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
if ping -c 1 192.168.0.1 > /dev/null; then
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

############################
# HERE'S THE ACTION PART :)
############################

apt-get install -q -y dhcp3-server

rm /etc/dhcp3/dhcpd.conf
touch /etc/dhcp3/dhcpd.conf

echo '
# DHCP konfigurasjon for lokalt nett

ddns-update-style none;

# setter en default for domene navn og navnetjener
option domain-name "DOMAIN";
option domain-name-servers DNSOTHER;

# Lease tid
default-lease-time 600;
max-lease-time 7200;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
log-facility local7;

subnet SUBNET netmask NETMASK {
        range RANGE_START RANGE_STOP;
        option routers ROUTER_IP;
}' >> /etc/dhcp3/dhcpd.conf

# Domenenavn
SPORSMAL="Skriv inn domenenavn:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DOMAIN=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	DOMAIN=$INPUT_LOWER_CASE
fi

# DNS ip-adress
# Her må det testes hvilken adresse vi kan bruke
SPORSMAL="Skriv inn ip til autorativ dns-tjener, forutsetter at internt nett er på eth1:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DNSOTHER=`/sbin/ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`
else
	DNSOTHER=$INPUT_LOWER_CASE
fi

# Her setter vi subnettet
SPORSMAL="Skriv inn subnett:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	SUBNET=0.0.0.0
else
	SUBNET=$INPUT_LOWER_CASE
fi

# Her setter vi nettmaska
SPORSMAL="Skriv inn nettmasken (ENTER: default 255.255.255.0):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	NETMASK=255.255.255.0
else
	NETMASK=$INPUT_LOWER_CASE
fi

# Her setter vi startip
SPORSMAL="Skriv inn første ip:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	RANGE_START=0.0.0.0
else
	RANGE_START=$INPUT_LOWER_CASE
fi

# Her setter vi stoppip
SPORSMAL="Skriv inn siste ip:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	RANGE_STOP=0.0.0.0
else
	RANGE_STOP=$INPUT_LOWER_CASE
fi

# Her setter vi ip-addressen til ruteren
SPORSMAL="Skriv inn ruter ip:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	ROUTER_IP=0.0.0.0
else
	ROUTER_IP=$INPUT_LOWER_CASE
fi

sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/DNSOTHER/"$DNSOTHER"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/SUBNET/"$SUBNET"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/NETMASK/"$NETMASK"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/RANGE_START/"$RANGE_START"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/RANGE_STOP/"$RANGE_STOP"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/ROUTER_IP/"$ROUTER_IP"/g" /etc/dhcp3/dhcpd.conf

/etc/init.d/dhcp3-server restart
