#!/bin/bash 

## 
# Automatisk oppsett av NFS-klient
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

apt-get install -qy nfs-common portmap

# Vi henter variabel input fra brukeren
TSHARE=""
IPADDR=""
KSHARE=""

SPORSMAL="Skriv inn navnet på tjener sharet (default er /home):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	TSHARE="/home"
else
	TSHARE=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn ip-addressen på tjeneren (default er ip på eth0):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	IPADDR=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | mawk '{ print $1 }'`
else
	IPADDR=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn navnet på klient sharet (default er /home, sharet blir laget i scriptet så benytt fullstendig bane):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	KSHARE="/home"
else
	KSHARE=$INPUT_LOWER_CASE
fi

mkdir -p $KSHARE

echo "
$IPADDR:$TSHARE  $KSHARE   nfs      rw,sync,hard,intr  0     0" >> /etc/fstab

