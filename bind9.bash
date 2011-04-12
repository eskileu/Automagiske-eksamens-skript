#!/bin/bash

#
# Installasjonsscript for bind9
#
## Rev. 0.3 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# 0.2 Scriptet er i beta versjon, dvs at det fungerer, men ikke
# testet av andre en dlill
# 0.3 fiksa på et duplikat innslag på en variabel, og lagt til at scriptet
#  selv finner reverse ip til subnettet
# -------------
# Last edit: Tue 11 Apr 2011
#
# TODO:
# 1. Testing av andre
##

###############
# Function
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
if ping -c 1 vg.no > /dev/null; then
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

IP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`

apt-get install -q -y bind9 bind9-doc resolvconf

# Rekonfigurere /etc/bind/named.conf.local

SPORSMAL="Skriv inn domenenavn:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DOMAIN=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	DOMAIN=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn ip-nettadresse (0.168.192):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	IP_1=`echo $IP | cut -d. -f3`
	IP_2=`echo $IP | cut -d. -f2`
	IP_3=`echo $IP | cut -d. -f1`
	IPREV=$IP_1.$IP_2.$IP_3
else
	IPREV=$INPUT_LOWER_CASE
fi

# Oppretter filen /etc/bind/named.conf.local
echo '
zone "DOMAIN" {  
        type master;
        file "/etc/bind/db.DOMAIN";
};
zone "IPREV.in-addr.arpa" {
        type master;
        notify no;
        file "/etc/bind/db.IPREV";
};' >> /etc/bind/named.conf.local

# Fikser på innslagene i filen med våre verdier på variablene
sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/bind/named.conf.local
sed -i "s/IPREV/"$IPREV"/g" /etc/bind/named.conf.local


# Lager innslagsfilene for domenet vårt
# Oppretter først filene på rett sted
touch /etc/bind/db.$DOMAIN 
touch /etc/bind/db.$IPREV

# Legger til våre innslage i filen /etc/bind/db.$DOMAIN
echo '
; BIND data fil for lokal loopback
;
@ORIGIN DOMAN.
$TTL    604800

@       IN      SOA     ns.DOMAIN. root.DOMAIN. (
                        1               ;Serial
                        604800          ;Refresh
                        86400           ;Retry
                        2419200         ;Expire
                        604800          ;Default TTL
)

@       IN      NS      ns.DOMAIN.
ns      IN      A       IP
box     IN      A       IP' >> /etc/bind/db.$DOMAIN

# Legger inn variablene brukeren har gitt oss
sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/bind/db.$DOMAIN
sed -i "s/IP/"$IP"/g" /etc/bind/db.$DOMAIN

# Populerer filen /etc/bind/db.$IPREV
echo '
;
; BIND reverse data fil for lokal loopback
;
$ORIGIN	DOMAIN.
$TTL    604800
@       IN      SOA     ns.DOMAIN. (
                        2       ;Serienummer
                        604800  ;Refresh
                        86400   ;Retry
                        2419200 ;Expire
                        604800) ;Negative Cache TTL
;
@       IN      NS      ns.
93      IN      PTR     ns.DOMAIN.' >> /etc/bind/db.$IPREV

# Legger inn variablene brukeren har gitt oss
sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/bind/db.$IPREV
sed -i "s/IP/"$IP"/g" /etc/bind/db.$IPREV


# Vi tester innstallasjonen
named-checkzone $DOMAIN /etc/bind/db.$DOMAIN

# Restarter tjenesten
/etc/init.d/bind9 restart

