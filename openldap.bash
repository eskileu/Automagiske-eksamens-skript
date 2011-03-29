#!/bin/bash

#
# Openldap script
#
## Rev. 0.21 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# 0.15 Lagt til de første elementene i innstallasjonen og lagt til alle 
# linjene i guiden (kommentert ut) slik at de kommer i riktig rekkefølge
# 0.2 Første beta versjon av fullstendig script
# 0.21 Noen mindre tweaks
# -------------
# Last edit: Sun 27 Mar 2011
#
# TODO:
# 1. Sjekke for faktiske feil
# 2. Rette opp hardlinking og ordne softlinks
# 3. Legge til funksjoner for opprydding cleanUp()
# 3.1 Fjerne temp filer
# 3.2 Fjerne testbruker
# 4. Legge til postconf informasjon 
# 5. Sjekke testrutiner som er kommentert ut
# 6. Legge til soft policy
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

#######################
# HERE'S THE ACTION :)
#######################

apt-get install -q -y slapd ldap-utils
dpkg-reconfigure slapd

# Konfigurerer /etc/ldap/ldap.conf

rm /etc/ldap/ldap.conf
touch /etc/ldap/ldap.conf
chmod 644 /etc/ldap/ldap.conf

SPORSMAL="Skriv inn fullstendig dc:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DC='dc=localdomain'
else
	DC=$INPUT_LOWER_CASE
fi
DC1='BASE   '$DC
echo $DC1 >> /etc/ldap/ldap.conf


SPORSMAL="Skriv inn intern ip-adresse:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	IP=`/sbin/ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`
else
	IP=$INPUT_LOWER_CASE
fi
IP1='URI   '$IP
echo $IP1 >> /etc/ldap/ldap.conf

#########################################################
# KJØRER EN SJEKK AT /etc/ldap/slapd.conf INNEHOLDER
# NOEN SCHEMA'ER SOM VI ER AVHENGIG AV FØR VI GÅR VIDERE
#########################################################

CORE=core.schema
COSINE=cosine.schema
NIS=nis.schema
INET=inetorgperson.schema

VARIABEL=`grep -e $CORE -e $COSINE -e $NIS -e $INET /etc/ldap/slapd.conf | wc -l`

if (($VARIABEL == 4)); then
        sed -i '/loglevel        none/ c\loglevel	256' /etc/ldap/slapd.conf
	sed -i '86 a\index	uid          eq' /etc/ldap/slapd.conf
else
        echo "dust"
fi


# REINDEKSERER 

/etc/init.d/slapd stop
slapindex
chown -R openldap:openldap /var/lib/ldap
/etc/init.d/slapd start


###########################################
# Lager 2 ou'er: People og Group i ou.ldif
###########################################

touch /tmp/ou.ldif
echo $DC
echo "
dn: ou=People,$DC
ou: People
objectClass: organizationalUnit

dn: ou=Group,$DC
ou: Group
objectClass: organizationalUnit" >> /tmp/ou.ldif

/etc/init.d/slapd stop
slapadd -c -v -l /tmp/ou.ldif
/etc/init.d/slapd start


# Lager en testbruker (goofy) for at vi skal se at alt er i orden 

touch /tmp/goofy.ldif

echo "
dn: cn=goofy,ou=group,$DC
cn: goofy
gidNumber: 20000
objectClass: top
objectClass: posixGroup

dn: uid=goofy,ou=people,$DC
uid: goofy
uidNumber: 20000
gidNumber: 20000
cn: goofy
sn: goofy
objectClass: top
objectClass: person
objectClass: posixAccount
objectClass: shadowAccount
loginShell: /bin/false
homeDirectory: /home/goofy" >> /tmp/goofy.ldif

ldapadd -c -x -D cn=admin,$DC -W -f /tmp/goofy.ldif


###############
# NSS og PAM
###############

apt-get install -q -y libnss-ldap

dpkg-reconfigure libnss-ldap

# Konfigurerer/etc/nsswitch.conf

sed -i 's|compat|files ldap|g' /etc/nsswitch.conf

/etc/init.d/nscd stop

dpkg-reconfigure libpam-ldap


# Konfigurere /etc/pam.d/common-account

sed -i '/pam_unix.so/d' /etc/pam.d/common-account
echo "
account sufficient      pam_ldap.so
account required        pam_unix.so try_first_pass
session required        pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-account

# Konfigurere /etc/pam.d/common-auth

sed -i '/pam_unix.so/d' /etc/pam.d/common-auth
echo "
auth    sufficient      pam_ldap.so
auth    required        pam_unix.so nullok_secure try_first_pass" >> /etc/pam.d/common-auth

# Konfigurere /etc/pam.d/common-password

sed -i '/pam_unix.so/d' /etc/pam.d/common-password
echo "
password   sufficient pam_ldap.so
password   required   pam_unix.so nullok obscure" >> /etc/pam.d/common-password

# Konfigurere /etc/pam.d/common-session

sed -i '/pam_unix.so/d' /etc/pam.d/common-session
echo "
session sufficient      pam_ldap.so
session required        pam_unix.so try_first_pass" >> /etc/pam.d/common-session

# Fikser "boot"-problemet
sed -i '/#bind_policy hard/ c\bind_policy soft' /etc/libnss-ldap.conf

