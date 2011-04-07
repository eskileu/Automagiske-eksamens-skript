#!/bin/bash


# Skript for å samle de ulike installasjonene.
# Tilbyr en dialog hvro brukere kan velge hva de vil kjøre
#
## Rev. 0.06 (1.0 er det samme som fult operativ)
# -------------
# 0.05 Startet på grunn strukturen.
# 0.06 Lagt til gateway installasjonen
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

if (( $UID != 0 )); then
	echo "*!* FATAL: Can only be executed by root."
	exit
fi
REDTEMP=$(tput setaf 1)
LIGHTCYANTEMP=$(tput bold ; tput setaf 6)
RESETTEMP=$(tput sgr0)

#if type -p dialog; then
#	DIALOG="$(type -p dialog) --backtitle Insta_Install_v0.05 --aspect 75"
#else
#	echo "Dialog ikke funnet ---> ${REDTEMP}apt-get install dialog${RESETTEMP}"
#	exit 1
#fi
#
if ping -c 1 158.38.48.10 > /dev/null; then
	echo "PING: OK"
else
	echo "PING: ${REDTEMP}FAILED${RESETTEMP}"
	echo "Skript avsluttet siden vi ikke har nett"
	exit
fi

TMPFIL="/tmp/`date +%N`.tmp"
touch $TMPFIL
INNHOLD=false



############################
#   -*-Input funksjon-*-   #     
############################
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


###################################
#   -*-Installasjons metoder-*-   #     
###################################

#----GATEWAY----#
instGateway(){
        touch /etc/init.d/fw-script.sh

        chmod +x /etc/init.d/fw-script.sh

        update-rc.d fw-script.sh defaults

        echo '
        #!/bin/sh
         
        PATH=/usr/sbin:/sbin:/bin:/usr/bin
         
        # Slette all regler
        iptables -F
        iptables -t nat -F
        iptables -t mangle -F
        iptables -X
         
        # Portforwarding
        # iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j REDIRECT --to-port SQUIDPORT
        # iptables -A INPUT -p tcp -m state --state NEW --dport 80 -i eth0 -j ACCEPT
         
        # Pakkeforwarding
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        iptables -A FORWARD -i eth1 -j ACCEPT
        iptables -A FORWARD -i eth2 -j ACCEPT
         
        # Alltid akseptere loopback
        iptables -A INPUT -i lo -j ACCEPT
         
        # Sørge for pakkeforwarding
        echo "1" > /proc/sys/net/ipv4/ip_forward' >> /etc/init.d/fw-script.sh

        /etc/init.d/fw-script.sh

        SPORSMAL="Skal du benytte squid? (1 for SQUID og 2 for ikke SQUID)"
        getInput 1
        if (( $INPUT_LOWER_CASE == 1)); then
	        SPORSMAL="Skriv inn portnummer på squid:"
	        getInput 1
	        if [ -z $INPUT_LOWER_CASE ]; then
		        SQUIDPORT=3128
	        else
		        SQUIDPORT=$INPUT_LOWER_CASE
	        fi

	        sed -i "s/SQUIDPORT/"$SQUIDPORT"/g" /etc/init.d/fw-script.sh
	        sed -i '13 s/^[#]\{1\}//g' /etc/init.d/fw-script.sh

	        /etc/init.d/fw-script.sh
        else
	        echo "Du har valgt å ikke implementere SQUID i brannmuren nå"
        fi
} # Slutt gateway


###############################
#    -*-DIALOG METODER-*-     #   
###############################

# Dialog metoden
installasjonsValg(){

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

# Sjekk av filmetode
sjekkFil(){
        #Kontroll på at TMPFIL ikke er tom
        if [ -s $1 ]; then
                echo "Det er gjort valg fra listen"
                INNHOLD=true
        else
                echo "Ingen ting ble valgt fra smørbrødslisten"
        fi 
}

# Les filen linje for linje metode
# Avdekker på denne måten brukervalgene

lesFil(){
        while read line ; do
                if [ "$line" == "GATE" ]; then
                        echo "GATE valgt"
                        instGateway
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

rydd(){
        #Fjerner tmp filen som ble opprettet i /tmp
        rm $TMPFIL

        #Andre ting som må ryddes under her
}


###############################
#-----------MAIN--------------#   
###############################

installasjonsValg      #Tilbyr installasjons valg

sjekkFil $TMPFIL       #Sjekker filen med valgene i

#Kjører kun om det er gjort valg
if ( $INNHOLD ) ; then
        lesFil          #Leser filene med valg om den har innhold
fi 

echo "Filen som ble opprettet finner du her: $TMPFIL"






