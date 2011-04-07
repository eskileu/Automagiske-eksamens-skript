#!/bin/bash

#
# Skript for å samle de ulike installasjonene.
# Tilbyr en dialog hvro brukere kan velge hva de vil kjøre
#
## Rev. 0.05 (1.0 er det samme som fult operativ)
# -------------
# 0.05 Startet på grunn strukturen.
# -------------
# Last edit: Thur 7 Apr 2011
#
# TODO:
# 1. Mate inn de ulike installasjonene
# 2. Teste ut at ting virker som det skal
# 3. TESTE ENDA MER!!
# 4. Samle sammen variablene så vi ikke har duplikater
# 5. Ta en øl
# 6. TBA
##

#if (( $UID != 0 )); then
#	echo "*!* FATAL: Can only be executed by root."
#	exit
#fi
#REDTEMP=$(tput setaf 1)
#LIGHTCYANTEMP=$(tput bold ; tput setaf 6)
#RESETTEMP=$(tput sgr0)

#if type -p dialog; then
#	DIALOG="$(type -p dialog) --backtitle Insta_Install_v0.05 --aspect 75"
#else
#	echo "Dialog ikke funnet ---> ${REDTEMP}apt-get install dialog${RESETTEMP}"
#	exit 1
#fi
#
#if ping -c 1 158.38.48.10 > /dev/null; then
#	echo "PING: OK"
#else
#	echo "PING: ${REDTEMP}FAILED${RESETTEMP}"
#	echo "Skript avsluttet siden vi ikke har nett"
#	exit
#fi

TMPFIL="/tmp/`date +%N`.tmp"
touch $TMPFIL
INNHOLD=false


# Dialog metoden
valg(){

        dialog --backtitle "Automagisk Eksamens Skript" \
                --title "Smørbrødlisten" \
                --checklist "Velg hva du vil installere..." 0 0 0 \
                "GATE"  "Setter på forwarding og oppretter et enkelt brannmurskript" ON \
                "DNS"	"Installasjon av bind9" off \
                "DHCP"	"Installasjon av dhcp3" off \
                "SAMDAP"  "Installasjon av openLDAP og Samba 3.X" off \
                "LAMP" 	"Installasjon av LAMP pakken og wordpress" off \
                "SQUID" "Installasjon av proxyen Squid3" off \
                "EPOST" "Installasjon av Postfix/Courier med tilbehør" off \
                "BPC"   "Installasjon av backupPC" off 2> $TMPFIL

        # Fjerner hermetegnene rundt valgene
        sed -i 's/"/\n/g' $TMPFIL
        # Fjerner tomme linjer
        sed -i '/^ *$/d' $TMPFIL
        clear
}

sjekkFil(){
        #Kontroll på at TMPFIL ikke er tom
        if [ -s $TMPFIL ]; then
                echo "Det er gjort valg fra listen"
                INNHOLD=true
        else
                echo "Ingen ting ble valgt fra smørbrødslisten"
        fi 
}

lesFil(){
        while read line ; do
                if [ "$line" == "GATE" ]; then
                        echo "GATE valgt"
                elif [ "$line" == "DNS" ]; then
                        echo "DNS valgt"
                elif [ "$line" == "DHCP" ]; then
                        echo "DHCP valgt"
                elif [ "$line" == "SAMDAP" ]; then
                        echo "SAMDAP valgt"
                elif [ "$line" == "LAMP" ]; then
                        echo "LAMP valgt"
                elif [ "$line" == "SQUID" ]; then
                        echo "SQUID valgt"
                elif [ "$line" == "EPOST" ]; then
                        echo "EPOST valgt"
                elif [ "$line" == "BPC" ]; then
                        echo "BPC valgt"
                fi
        done < $TMPFIL
}




###############################
#        -*-MAIN-*-           #   
###############################

valg            #Tilbyr installasjons valg

sjekkFil        #Sjekker filen med valgene i

#Kjører kun om det er gjort valg
if ( $INNHOLD ) ; then
        lesFil          #Leser filene med valg om den har innhold
fi 

echo "Filen som ble opprettet finner du her: $TMPFIL"






