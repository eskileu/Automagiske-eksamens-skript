#!/bin/bash 

## 
# Automatisert epost installasjon
# Rev. 0.1 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# -------------
# 
#
# TODO:
# 1. Skaff en oversikt over alle konfigurasjonsfilene som er nødvendig
# 2. Få på plass variabler som vi trenger til konfigurasjonsfilene
# 3. Legge til installasjon av postfix
# 4. Legge til installasjon av courier
# 5. Legge til installasjon av amavis med clamav til virus og spamassassin til spam
# 6. Legge til installasjon av postgrey og policy-weight
# 7. Finne ut om vi kan mate inn verdier i konfigdialoger under installasjon.
##


##################################################
# UNDER DETTE SKILLET SKAL KUN FUNKSJONER LIGGE  #
# FUNKSJONER MÅ VIST LESES FØRST...              #
##################################################

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
echo "
Dette skriptet vil automatisere installasjonen av en epost løsning.
Sørg for at du har riktige innstillinger knyttet til hostname, IP, domene og
dns før du går videre. Er du usikker så avbryt og dobbelsjekk dine innstillinger!!"
echo " "
pause "Om du er sikker trykk ENTER eller avbryt med CTRL+C"

##
# Variablelkassen. Kom med innspill her på hvilke verdier som vi trenger.
##

# Konfig variabler
HOSTNAVN="" # Denne MÅ vi ha
DOMENE=""   # Denne MÅ vi ha
HOSTIP=""   # Denne MÅ vi ha
EKSTERNT_INTERFACE="" # Om noen skulle bruke noe annet en eth0

SPORSMAL="Hvilken hostname har serveren: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	HOSTNAVN=`hostname`
else
	HOSTNAVN=$INPUT_LOWER_CASE
fi

SPORSMAL="Hvilket domene skal serveren benytte: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DOMENE=`hostname -d`
else
	DOMENE=$INPUT_LOWER_CASE
fi

SPORSMAL="Hvilket interface er det eksterne: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	EKSTERNT_INTERFACE="eth0"
else
	EKSTERNT_INTERFACE=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn serveren sin eksterne IP adresse:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	HOSTIP=`ifconfig $EKSTERNT_INTERFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
else
	HOSTIP=$INPUT_LOWER_CASE
fi


###################
# POSTFIX OG SASL #
###################
echo " "
echo "STARTER INSTALLASJON AV POSTFIX"
echo " "
apt-get update
apt-get -qy install postfix sasl2-bin procmail libsasl2-modules

postconf -e 'smtpd_sasl_local_domain ='
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'broken_sasl_auth_clients = yes'
postconf -e 'smtpd_sasl_authenticated_header = yes'
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination'
postconf -e 'inet_interfaces = all'

touch /etc/postfix/sasl/smtpd.conf
echo 'pwcheck_method: saslauthd' >> /etc/postfix/sasl/smtpd.conf
echo 'mech_list: plain login' >> /etc/postfix/sasl/smtpd.conf

# Fiks av rettigheter mellom sasl og postfix
rm -r /var/run/saslauthd/
mkdir -p /var/spool/postfix/var/run/saslauthd
ln -s /var/spool/postfix/var/run/saslauthd /var/run
chgrp sasl /var/spool/postfix/var/run/saslauthd
adduser postfix sasl

# Opprette ssl nøkler til postfix
mkdir /etc/postfix/ssl
cd /etc/postfix/ssl/
openssl genrsa -des3 -rand /etc/hosts -out smtpd.key 1024
chmod 600 smtpd.key
openssl req -new -key smtpd.key -out smtpd.csr
openssl x509 -req -days 3650 -in smtpd.csr -signkey smtpd.key -out smtpd.crt
openssl rsa -in smtpd.key -out smtpd.key.unencrypted
mv -f smtpd.key.unencrypted smtpd.key
openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650

postconf -e "myhostname = $HOSTNAVN.$DOMENE"
postconf -e 'smtpd_tls_auth_only = no'
postconf -e 'smtp_use_tls = yes'
postconf -e 'smtpd_use_tls = yes'
postconf -e 'smtp_tls_note_starttls_offer = yes'
postconf -e 'smtpd_tls_key_file = /etc/postfix/ssl/smtpd.key'
postconf -e 'smtpd_tls_cert_file = /etc/postfix/ssl/smtpd.crt'
postconf -e 'smtpd_tls_CAfile = /etc/postfix/ssl/cacert.pem'
postconf -e 'smtpd_tls_loglevel = 1'
postconf -e 'smtpd_tls_received_header = yes'
postconf -e 'smtpd_tls_session_cache_timeout = 3600s'
postconf -e 'tls_random_source = dev:/dev/urandom'

mkdir -p /var/spool/postfix/var/run/saslauthd
sed -i '/START=no/ c\START=yes' /etc/default/saslauthd
sed -i 's|"-c -m /var/run/saslauthd"|"-c -m /var/spool/postfix/var/run/saslauthd"|g' /etc/default/saslauthd

# Restart sasl og postfix
/etc/init.d/postfix restart
/etc/init.d/saslauthd restart

### Legg inn varsling om telnet test og en mulighet til å avbryte om noe skulle være feil
## tekstsnutt som forklarer telnet bruk og etter test en pause hvor vi git muligheten til å avbryte

echo "
STEG 1 FERDIG!
Gjennomfør en telnet test for å sjekke at postfix er tilgjengelig.
Ta en ${LIGHTCYANTEMP}ehlo localhost${RESETTEMP} i telnet. Se etter AUTH PLAIN
og TLS.
"
telnet localhost 25
pause "Om alt ser ut til å være korrekt trykk ENTER. Avbryt eventuelt med CTRL+C"

###########
# COURIER #
###########
echo "
START COURIER INNSTALLASJON OG KONFIGURASJON
"
apt-get install -qy courier-authdaemon courier-base courier-imap courier-imap-ssl courier-pop courier-pop-ssl courier-ssl gamin libgamin0 libglib2.0-0

###########
# CLAMAV  #
###########
echo "
START CLAMAV INNSTALLASJON OG KONFIGURASJON
"
apt-get install -qy clamav clamav-docs clamav-daemon clamav-freshclam
apt-get install -qy arc arj bzip2 cabextract lzop nomarch p7zip pax tnef unrar-free unzip zoo ripole
echo "deb http://ftp.no.debian.org/debian/ lenny non-free" >> /etc/apt/sources.list
apt-get install -qy lha unrar
apt-get install -qy clamav-testfiles
clamscan /usr/share/clamav-testfiles
clamdscan /usr/share/clamav-testfiles/
apt-get remove clamav-testfiles

#################
# SPAMASSASSIN  #
#################
echo "
START SPAMASSASSIN INNSTALLASJON OG KONFIGURASJON
"
apt-get install -qy spamassassin spamc
apt-get install -qy razor pyzor

sed -i '/ENABLED=0/ c\ENABLED=1' /etc/default/spamassassin
sed -i '/CRON=0/ c\CRON=1' /etc/default/spamassassin


















