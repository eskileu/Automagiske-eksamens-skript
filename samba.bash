#!/bin/bash

# Samba
# ver 0.1 skjellett

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

# Her kommer LDAP-tingene
ldap suffix = dc=atlas,dc=localdomain
ldap user suffix = ou=People
ldap group suffix = ou=Group
ldap machine suffix = ou=People
ldap idmap suffix = ou=Idmap
ldap passwd sync = yes
ldap admin dn = cn=admin,dc=atlas,dc=localdomain

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
   path = /home/delt
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

#SPORSMAL="Sett en server string for beskrivelse av serveren: "
#getInput 1
#if [ -z $INPUT_LOWER_CASE ]; then
#	SERVER_STRING=""
#else
#	SERVER_STRING=$INPUT_LOWER_CASE
#fi
#echo $SERVER_STRING
# sed -i "s/SERVER_STRING/"$SERVER_STRING"/g" /etc/samba/smb.conf

#SPORSMAL="Skriv inn PATH til share: "
#getInput 1
#if [ -z $INPUT_LOWER_CASE ]; then
#	SHARE_PATH=""
#else
#	SHARE_PATH=$INPUT_LOWER_CASE
#fi
#echo $SHARE_PATH
# sed -i "s/SHARE_PATH/"$SHARE_PATH"/g" /etc/samba/smb.conf

echo "setter smbpassord for janmag"
smbpasswd -U janmag

echo "tester oppsettet"
smbclient -U janmag -L localhost


# PDC

mkdir -m 0755 /var/lib/samba/netlogon

echo 'net use w: \\2badr-gr5-m2\samba-share /P:No /yes' > /var/lib/samba/netlogon/netlogon.bat

echo "setter root passord"
smbpasswd -a

echo "setter passord for klientmaskin"
groupadd maskiner
useradd -g maskiner -d /dev/null -s /bin/false winxp\$
smbpasswd -a -m winxp


# Integrere Samba og LDAP

apt-get install -q -y smbldap-tools

cp /usr/share/doc/samba-doc/examples/LDAP/samba.schema.gz /etc/ldap/schema/
gunzip /etc/ldap/schema/samba.schema.gz

sed -i '14 a\include        /etc/ldap/schema/samba.schema' /etc/ldap/slapd.conf

/etc/init.d/slapd restart
/etc/init.d/samba restart

# her må vi gjøre noe
echo "setter ldap passord i samba"
smbpasswd -w 1234

echo '
############################
# Credential Configuration #
############################
# Notes: you can specify two differents configuration if you use a
# master ldap for writing access and a slave ldap server for reading access
# By default, we will use the same DN (so it will work for standard Samba
# release)
slaveDN="cn=admin,dc=atlas,dc=localdomain"
slavePw="1234"
masterDN="cn=admin,dc=atlas,dc=localdomain"
masterPw="1234"' > /etc/smbldap-tools/smbldap_bind.conf

chmod 600 /etc/smbldap-tools/smbldap_bind.conf

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
suffix="dc=atlas,dc=localdomain"

usersdn="ou=People,${suffix}"
computersdn="ou=People,${suffix}"
groupsdn="ou=Group,${suffix}"
idmapdn="ou=Idmap,${suffix}"
sambaUnixIdPooldn="sambaDomainName=atlas,dc=localdomain"

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
userSmbHome="\\atlas\homes\%U"

# The UNC path to profiles locations (%U username substitution)
userProfile="\\atlas\profiles\%U"

# The default Home Drive Letter mapping
userHomeDrive="H:"

# The default user netlogon script name (%U username substitution)
userScript=startup.cmd

# Domain appended to the users "mail"-attribute
mailDomain="atlas.localdomain"

# SMBLDAP-TOOLS Configuration (default are ok for a RedHat)

# Allows not to use smbpasswd
smbpasswd="/usr/bin/smbpasswd"' >> /etc/smbldap-tools/smbldap.conf

#sed -i "s/LOCALSID/"$LOCALSID"/g" /etc/smbldap-tools/smbldap.conf
#sed -i "s/LOCALSID/"`net getlocalsid`"/g" /etc/smbldap-tools/smbldap.conf

smbldap-populate -e populate.ldif

smbldap-populate
