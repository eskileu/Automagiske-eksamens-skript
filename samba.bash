#!/bin/bash

# Samba

#############
# Funksjoner
#############

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

#############
# Action del
#############

apt-get install -q -y samba samba-doc

apt-get install -q -y smbclient

SHARE_PATH=`mkdir /home/delt`

rm /etc/samba/smb.conf
touch /etc/samba/smb.conf

echo '
#======================= Global Settings =======================

[global]

## Browsing/Identification ###

# Change this to the workgroup/NT-domain name your Samba server will part of
   workgroup = WORKGROUP

#  Maskinnavnet som jeg satte på Linux-en som kjører Sambaen
   netbios name = NETBIOS_NAME
   server string = SERVER_STRING
   domain master = yes

# Sikre at det er Samba-tjeneren som brukes som domenekontroller. Poenget er å sette
# høyt nok tall. Ingen Windows-tjenere går høyere enn 32
   os level = 34

#  Dette valget har med network browsing å gjøre, dvs at Samba-tjenere vises i Windows
#  Network Neighbourhood.
   preferred master = yes

#  Dette valget sier at Samba-tjeneren skal stå for nettverks-login for Windows-klientene.
   domain logons = yes

#  Legger til nye maskiner etter hvert som det logges inn fra nye maskiner
#  som pr nå ikke er registrert i Samba-tjeneren.
   add machine script = /usr/sbin/useradd -s /bin/false -d /dev/null -g maskiner /047%u/047

#  Angir hvilken databaseløsning som er valg for å lagre passordene.
#  Seinere skal vi her bruke LDAP-basen.
   passdb backend = tdbsam

#  Sikkerheten settes til brukernivå. Finnes andre valg også, f.eks share, domain, ADS
   security = user
   encrypt passwords = yes

   logfile = /var/log/samba/log
   log level = 2
   max log size = 50

#  Bruker Sambas egen navnetjeneste.
   wins support = yes

#  Inneholder bl.a montering av øvrige share enn hjemmemappen (som alle får)
   logon script = netlogon.bat

[netlogon]
   comment = Network Logon Service

#  Her ligger filen netlogon.bat. Se ovenfor
   path = /var/lib/samba/netlogon
   browseable = No
   writable = No



#======================= Share Definitions =======================

[samba-share]
   comment=Denne mappen inneholder delte dokumenter
   path = SHARE_PATH
   public = yes
   writable = yes


[homes]
   comment = Home Directories

# Brukerne vil automatisk få montert opp sine hjemmemapper.
# valid users angir hvilke brukere som har tilgang.
   valid users = %S
   browseable = no
   writable = yes' >> /etc/samba/smb.conf


SPORSMAL="Hvilken Workgroup har serveren: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	WORKGROUP=""
else
	WORKGROUP=$INPUT_LOWER_CASE
fi

sed -i "s/WORKGROUP/"$WORKGROUP"/g" /etc/samba/smb.conf

SPORSMAL="Hvilken NetBios navn har serveren: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	NETBIOS_NAME=""
else
	NETBIOS_NAME=$INPUT_LOWER_CASE
fi

sed -i "s/NETBIOS_NAME/"$NETBIOS_NAME"/g" /etc/samba/smb.conf

SPORSMAL="Sett en server string for beskrivelse av serveren: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	SERVER_STRING=""
else
	SERVER_STRING=$INPUT_LOWER_CASE
fi
echo $SERVER_STRING
# sed -i "s/SERVER_STRING/"$SERVER_STRING"/g" /etc/samba/smb.conf

SPORSMAL="Skriv inn PATH til share: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	SHARE_PATH=""
else
	SHARE_PATH=$INPUT_LOWER_CASE
fi
echo $SHARE_PATH
# sed -i "s/SHARE_PATH/"$SHARE_PATH"/g" /etc/samba/smb.conf

# sudo smbpasswd -U <brukernavn>

# smbclient -U <brukenavn> -L localhost


