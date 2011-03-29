#!/bin/bash 

## 
# Automatisert squid3 installasjon
# Rev. 0.1 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Kommet i gang i det minste. 
# Må få orndet med kvalitetssjekk av input.
# -------------
# 
#
# TODO:
##


##################################################
# UNDER DETTE SKILLET SKAL KUN FUNKSJONER LIGGE  #
# FUNKSJONER MÅ VIST LESES FØRST...              #
##################################################


# Rydde funksjon. Kun et skjelett må fylles
function cleanUp()
{
	echo "Fjerner pakker som har blitt installert"
}

# Pause funksjon som krever [ENTER] for å fortsette
function pause(){
	read -p "$*"
}

# Funksjon for kontroll av input. Må endres slik at den 
# passer inputen forventet til epost oppsettet. Hentet fra tihlde skript.
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

######################################################
# UNDER DETTE SKILLET SKAL DEN UTFØRENDE KODEN LIGGE #
######################################################

TEMP=$1 # Forbanna $1 funket dårlig direkte i if setningen....
# Kommenter ut når rev er testet. 
if [ "$TEMP" != "test" ]; then
	echo "Det jobbes med scriptet for øyeblikket vennligst prøv igjen senere"
	exit
fi

# Sikre at kun root kan kjøre skriptet.
if (( $UID != 0 )); then
	echo "*!* FATAL: Can only be executed by root."
	exit
fi

if [ "$TEMP" == "rensk" ]; then
	cleanUp
	exit
fi

REDTEMP=$(tput setaf 1)
LIGHTCYANTEMP=$(tput bold ; tput setaf 6)
RESETTEMP=$(tput sgr0)

# Vi er avhengig av nett til installasjonene så vi gjør en pingtest
if ping -c 1 158.38.48.10 > /dev/null; then
	echo "PING: OK"
else
	echo "PING: ${REDTEMP}FAILED${RESETTEMP}"
	echo "Skript avsluttet siden vi ikke har nett"
	exit
fi

# Verifiser at brukeren virkelig vil gå videre
echo " "
pause "Om du er sikker trykk ENTER eller avbryt med CTRL+C"

##
# Variablelkassen. Kom med innspill her på hvilke verdier som vi trenger.
##

# Konfig variabler
INTERNIP=""
PORT=""
NETTMASKE=""
CIDR=""


SPORSMAL="Hva er IP adressen skal squid benytte? "
getInput 1
INTERNIP=$INPUT

SPORSMAL="Hvilken port vil du at squid skal bruke? "
getInput 1
PORT=$INPUT

SPORSMAL="Hva er nettmasken som skal benyttes? "
getInput 1
NETTMASKE=$INPUT

SPORSMAL="Skriv inn din nettadresse med CIDR notasjon (192.168.145.0/24): "
getInput 1
CIDR=$INPUT


##
# Installasjon av squid3
##
apt-get install -qy squid3

mkdir /etc/squid3/acl
cd /etc/squid3/acl
touch denied_ads.acl denied_domains.acl denied_filetypes.acl

##
# Fyll acl filer med test innhold
##
echo ".vg.no
.sex.com
.hackers.com
.xemacs.org
.stormtroopers.no" > /etc/squid3/acl/denied_domains.acl

echo "/adv/.*\.gif$
/[Aa]ds/.*\.gif$
/[Aa]d[Pp]ix/
/[Aa]d[Ss]erver
/[Aa][Dd]/.*\.[GgJj][IiPp][FfGg]$
/[Bb]annerads/" > /etc/squid3/acl/denied_ads.acl

echo "\.(exe)$
\.(zip)$
\.(mp3)$
\.(avi)$" > /etc/squid3/acl/denied_filetypes.acl

##
# Konfigurasjon squid3
##
cp /etc/squid3/squid.conf /etc/squid3/squid.conf.old

echo "http_port $INTERNIP:$PORT transparent
client_netmask $NETTMASKE
http_port $PORT transparent
acl our_networks src $CIDR
acl localnet src 127.0.0.1/255.255.255.255
acl denied_domains dstdomain "/etc/squid3/acl/denied_domains.acl"
acl filetypes urlpath_regex -i "/etc/squid3/acl/denied_filetypes.acl"
acl url_ads url_regex "/etc/squid3/acl/denied_ads.acl"

http_access deny denied_domains
http_access deny filetypes
http_access deny url_ads
http_access allow our_networks
http_access allow localnet
cache_mem 100 MB
cache_dir ufs /var/spool/squid3 300 16 256
access_log /var/log/squid3/access.log squid
coredump_dir /var/spool/squid3" > /etc/squid3/squid.conf

# Restart av squid3
/etc/init.d/squid3 rnanoestart

echo '
Ferdig!!
Du må fortsatt sette iptables regelen. (Eskil vi setter den i gateway scriptet, eller? :))
Eksempel:
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j REDIRECT --to-port $PORT
'


