#!/bin/bash

#
# Installasjonsscript for backuppc-klient
#
## Rev. 0.1 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# 0.2 Fjernet functions fordi vi ikke skal ha trenger noen input.
# TODO:
# 
##


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
if ping -c 1 158.38.56.1 > /dev/null; then
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

############
# ACTION!
############

apt-get install -qy rsync openssh-server

mkdir /root/.ssh
