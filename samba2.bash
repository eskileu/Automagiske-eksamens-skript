#!/bin/bash

#
# Samba script
#
## Rev. 0.3beta (1.0 er det samme som fult operativ)
# -------------
# 0.3 testet til beta release, trenger ekstern sjekk
# -------------
# Last edit: Wed 30 Mar 2011
#
# TODO:
# 1. Sjekke for faktiske feil
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

###########
# ACTION!
###########

apt-get install -qy samba samba-doc smbfs

apt-get install -qy smbclient

mkdir /home/delt

###############################
# lager ny /etc/samba/smb.conf
###############################

rm /etc/samba/smb.conf

SPORSMAL="Skriv inn ldapsuffix på full form:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	LDAPSUFFIX=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	LDAPSUFFIX=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn sambadomene:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	WORKGROUP=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	WORKGROUP=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn navnet på tjeneren:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	NETBIOSNAME=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	NETBIOSNAME=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn passordet på ldap:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	LDAPPASSWORD=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	LDAPPASSWORD=$INPUT_LOWER_CASE
fi


echo '
#======================= Global Settings =======================

[global]

# Her kommer LDAP-tingene

ldap suffix = LDAPSUFFIX
ldap user suffix = ou=People
ldap group suffix = ou=Group
ldap machine suffix = ou=People
ldap idmap suffix = ou=Idmap
ldap passwd sync = yes
ldap admin dn = cn=admin,LDAPSUFFIX

passdb backend = ldapsam:ldap://localhost/
nt acl support = no

add user script = /usr/sbin/smbldap-useradd -m "%u"
ldap delete dn = Yes
#delete user script = /usr/sbin/smbldap-userdel "%u"
add machine script = /usr/sbin/smbldap-useradd -w "%u"
add group script = /usr/sbin/smbldap-groupadd -p "%g"
#delete group script = /usr/sbin/smbldap-groupdel "%g"
add user to group script = /usr/sbin/smbldap-groupmod -m "%u" "%g"
delete user from group script = /usr/sbin/smbldap-groupmod -x "%u" "%g"
set primary group script = /usr/sbin/smbldap-usermod -g "%g" "%u"

## Browsing/Identification ###

# Change this to the workgroup/NT-domain name your Samba server will part of
   workgroup = WORKGROUP

#  Maskinnavnet som jeg satte på Linux-en som kjører Sambaen
   netbios name = NETBIOSNAME
   server string = fil tjener
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
   add machine script = /usr/sbin/useradd -s /bin/false -d /dev/null -g maskiner "%u"

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
   path = /home/delt
   public = yes
   writable = no


[homes]
   comment = Home Directories

# Brukerne vil automatisk få montert opp sine hjemmemapper.
# valid users angir hvilke brukere som har tilgang.
   valid users = %S
   browseable = no
   writable = yes' > /etc/samba/smb.conf

sed -i "s/LDAPSUFFIX/"$LDAPSUFFIX"/g" /etc/samba/smb.conf
sed -i "s/WORKGROUP/"$WORKGROUP"/g" /etc/samba/smb.conf
sed -i "s/NETBIOSNAME/"$NETBIOSNAME"/g" /etc/samba/smb.conf


##################################
# avslutt smb.conf
##################################

mkdir -m 0755 /var/lib/samba/netlogon

echo "net use w: \\$NETBIOSNAME\samba-share /P:No /yes" > /var/lib/samba/netlogon/netlogon.bat

# root passord 2 ganger
echo "Sett root passord for root:"
smbpasswd -a

# Legge til en gruppe for maskiner (undersøke om dette er nødvendig)
groupadd maskiner
useradd -g maskiner -d /dev/null -s /bin/false winxp\$
smbpasswd -a -m winxp

apt-get install -qy smbldap-tools

cp /usr/share/doc/samba-doc/examples/LDAP/samba.schema.gz /etc/ldap/schema/

gunzip /etc/ldap/schema/samba.schema.gz

sed -i '14 a\include        /etc/ldap/schema/samba.schema' /etc/ldap/slapd.conf

/etc/init.d/slapd restart

/etc/init.d/samba restart

SPORSMAL="ldap admin passord:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	PASSORD=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	PASSORD=$INPUT_LOWER_CASE
fi

smbpasswd -U root -w $PASSORD

################################
# Kopiere inn smbldap.conf fila
################################
echo '
############################
# Credential Configuration #
############################
# Notes: you can specify two differents configuration if you use a
# master ldap for writing access and a slave ldap server for reading access
# By default, we will use the same DN (so it will work for standard Samba
# release)
slaveDN="cn=admin,LDAPSUFFIX"
slavePw="LDAPPASSWORD"
masterDN="cn=admin,LDAPSUFFIX"
masterPw="LDAPPASSWORD"' > /etc/smbldap-tools/smbldap_bind.conf

sed -i "s/LDAPSUFFIX/"$LDAPSUFFIX"/g" /etc/smbldap-tools/smbldap_bind.conf
sed -i "s/LDAPPASSWORD/"$LDAPPASSWORD"/g" /etc/smbldap-tools/smbldap_bind.conf

chmod 600 /etc/smbldap-tools/smbldap_bind.conf

#############################################
# Konfigurere/etc/smbldap-tools/smbldap.conf
#############################################

LOCALSID=`net getlocalsid | mawk '{ print $6 }'`
echo $LOCALSID

echo "
# General Configuration
SID="$LOCALSID"" > /etc/smbldap-tools/smbldap.conf

echo '
# LDAP Configuration
slaveLDAP="127.0.0.1"
slavePort="389"

masterLDAP="127.0.0.1"
masterPort="389"

# Use TLS for LDAP
ldapTLS="0"

verify="none"

# CA certificate
cafile="/etc/smbldap-tools/ca.pem"

clientcert="/etc/smbldap-tools/smbldap-tools.pem"

clientkey="/etc/smbldap-tools/smbldap-tools.key"

# LDAP Suffix
suffix="LDAPSUFFIX"

usersdn="ou=People,${suffix}"
computersdn="ou=People,${suffix}"
groupsdn="ou=Group,${suffix}"
idmapdn="ou=Idmap,${suffix}"
sambaUnixIdPooldn="sambaDomainName=WORKGROUP,LDAPSUFFIX"

# Default scope Used
scope="sub"

hash_encrypt="MD5"

crypt_salt_format="%s"


# Unix Accounts Configuration

userLoginShell="/bin/bash"

# Home directory
userHome="/home/%U"

# Gecos
userGecos="System User"

# Default User (POSIX and Samba) GID
defaultUserGid="513"

# Default Computer (Samba) GID
defaultComputerGid="515"

# Skel dir
skeletonDir="/etc/skel"

defaultMaxPasswordAge="99"


# SAMBA Configuration

# The UNC path to home drives location (%U username substitution)
userSmbHome="\\NETBIOSNAME\homes\%U"

# The UNC path to profiles locations (%U username substitution)
userProfile="\\NETBIOSNAME\profiles\%U"

# The default Home Drive Letter mapping
userHomeDrive="H:"

# The default user netlogon script name (%U username substitution)
userScript=startup.cmd

# Domain appended to the users "mail"-attribute
mailDomain="NETBIOSNAME.localdomain"

# SMBLDAP-TOOLS Configuration (default are ok for a RedHat)

# Allows not to use smbpasswd
smbpasswd="/usr/bin/smbpasswd"' >> /etc/smbldap-tools/smbldap.conf

sed -i "s/LDAPSUFFIX/"$LDAPSUFFIX"/g" /etc/smbldap-tools/smbldap.conf
sed -i "s/WORKGROUP/"$WORKGROUP"/g" /etc/smbldap-tools/smbldap.conf
sed -i "s/NETBIOSNAME/"$NETBIOSNAME"/g" /etc/smbldap-tools/smbldap.conf

# setter passord på bruker
# smbpasswd -U janmag
# tester klient oppsett
# smbclient -U janmag -L localhost



