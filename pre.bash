#!/bin/bash 

## 
# Skript som installerer en del pakker som det er praktisk å ha
# før selve installasjonene av ulike tjenster.
##

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
if ping -c 1 vg.no > /dev/null; then
	echo "PING: OK"
else
	echo "PING: ${REDTEMP}FAILED${RESETTEMP}"
	echo "Skript avsluttet siden vi ikke har nett"
	exit
fi

apt-get update
apt-get install -qy openssh-server sudo htop screen openssl quota quotatool acl dialog
echo "Husk å slå av muligheten til å logge inn som root etter at
sudo er konfigurert ---> /etc/ssh/sshd_config"

