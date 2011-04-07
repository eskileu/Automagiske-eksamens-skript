#!/bin/bash

#
# Installasjonsscript for å sette opp pdc
# vha Samba og OpenLDAP
## Rev. 0.1 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Scriptet er hardkodet
#  og fungerer nå med dette.
# 0.2 Byttet ut hardkoding med variabler, testet hjemme
#  trenger testing av andre. Samtidig kommentert script
# 0.3 Testet på nytt, fjernet invalid user root for å kunne
#  melde win klienter inn i domenet
# -------------
# Last edit: Thur 7 Apr 2011
#
# TODO:
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

############################
# HERE'S THE ACTION PART :)
############################

# Innstallere ldap daemon med tillegspakker
apt-get install -qy slapd

apt-get install -qy ldap-utils

apt-get install -qy libnss-ldap

# Rekonfigurerer for å sikre at detaljene stemmer
dpkg-reconfigure slapd

dpkg-reconfigure libnss-ldap

dpkg-reconfigure libpam-ldap


# redigere /etc/nsswitch.conf
sed -i 's|compat|files ldap|g' /etc/nsswitch.conf


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

# Fjerne hash tegnet foran host i disse filene
sed -i '21 s/^[#]\{1\}//g' /etc/pam_ldap.conf
sed -i '21 s/^[#]\{1\}//g' /etc/libnss-ldap.conf

# Restarter ldap daemon
/etc/init.d/slapd restart

LDAPSUFFIX=""
SPORSMAL="Skriv inn ldap suffix:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	LDAPSUFFIX=BYTTUTDETTEMEDENGANG
else
	LDAPSUFFIX=$INPUT_LOWER_CASE
fi

# Oppretter initielle grupper i ldap db
touch /tmp/initdb.ldif
echo "
dn: cn=nss,$LDAPSUFFIX
objectClass: organizationalRole
objectClass: simpleSecurityObject
cn: nss
description: LDAP NSS user for user-lookups
userPassword:: 0NSWVBUfXh4eHh4eHh4eHg=9

dn: ou=People,$LDAPSUFFIX
objectClass: organizationalUnit
objectClass: top
ou: People

dn: ou=Group,$LDAPSUFFIX
objectClass: top
objectClass: organizationalUnit
ou: Group" >> /tmp/initdb.ldif

ldapadd -x -W -a -D "cn=admin,$LDAPSUFFIX" -f /tmp/initdb.ldif

##################################
# Starter på SAMBA innstallasjonen
##################################

apt-get install -qy samba samba-doc

# Oppretter fellesmappe
mkdir /home/felles

# Kopierer schema for samba inn i ldap db
cp /usr/share/doc/samba-doc/examples/LDAP/samba.schema.gz /etc/ldap/schema/

# Pakker ut filen
gunzip /etc/ldap/schema/samba.schema.gz

# Legger til schema til ldap konfigurasjonen
sed -i '14 a\include        /etc/ldap/schema/samba.schema' /etc/ldap/slapd.conf

# Restarter ldap daemon
/etc/init.d/slapd restart

# Oppretter netlogon mappe og profil mappe
mkdir -p /home/samba/netlogon
mkdir -p /home/samba/profiles


# Legger inn /etc/samba/smb.conf

SPORSMAL="Skriv inn navnet på maskinen:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	NETBIOS_NAME=BYTTUTDETTEMEDENGANG
else
	NETBIOS_NAME=$INPUT_LOWER_CASE
fi


SPORSMAL="Skriv inn navnet på samba domenet:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	SMBDOMENE=BYTTUTDETTEMEDENGANG
else
	SMBDOMENE=$INPUT_LOWER_CASE
fi

 
echo '
#
# Sample configuration file for the Samba suite for Debian GNU/Linux.
#
#
# This is the main Samba configuration file. You should read the
# smb.conf(5) manual page in order to understand the options listed
# here. Samba has a huge number of configurable options most of which 
# are not shown in this example
#
# Any line which starts with a ; (semi-colon) or a # (hash) 
# is a comment and is ignored. In this example we will use a #
# for commentary and a ; for parts of the config file that you
# may wish to enable
#
# NOTE: Whenever you modify this file you should run the command
# "testparm" to check that you have not many any basic syntactic 
# errors. 
#

#======================= Global Settings =======================

[global]


#Sikre passord:

lanman auth = no 
lm announce = no 
min protocol = NT1


#PDC
domain logons = yes
os level = 33
preferred master = yes
domain master = yes
local master = yes
logon path = \\%N\profiles\%u
logon drive = H:
logon home = \\homeserver\%u\winprofile
logon script = startup.cmd
netbios name = NETBIOS_NAME

#Støtte for windows "user manager utility"
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
   workgroup = SMBDOMENE

# server string is the equivalent of the NT Description field
   server string = %h server (Samba %v)

# Windows Internet Name Serving Support Section:
# WINS Support - Tells the NMBD component of Samba to enable its WINS Server
;   wins support = no

# WINS Server - Tells the NMBD components of Samba to be a WINS Client
# Note: Samba can be either a WINS Server, or a WINS Client, but NOT both
;   wins server = w.x.y.z

# This will prevent nmbd to search for NetBIOS names through DNS.
   dns proxy = no

# What naming service and in what order should we use to resolve host names
# to IP addresses
;   name resolve order = lmhosts host wins bcast


#### Debugging/Accounting ####

# This tells Samba to use a separate log file for each machine
# that connects
   log file = /var/log/samba/log.%m

# Put a capping on the size of the log files (in Kb).
   max log size = 1000

# If you want Samba to only log through syslog then set the following
# parameter to yes.
;   syslog only = no

# We want Samba to log a minimum amount of information to syslog. Everything
# should go to /var/log/samba/log.{smbd,nmbd} instead. If you want to log
# through syslog you should set the following parameter to something higher.
   syslog = 0

# Do something sensible when Samba crashes: mail the admin a backtrace
   panic action = /usr/share/samba/panic-action %d


####### Authentication #######

#DN for administratoren
ldap admin dn = cn=admin,LDAPSUFFIX

#Fellesdel av DN for brukernavn (tillegg til uid=navn)
ldap suffix = ou=People,LDAPSUFFIX

#Fellesdel av DN for grupper
ldap group suffix = ou=Group,LDAPSUFFIX

#Synkroniser passordet i ldap med samba-passordet
ldap passwd sync = yes

ldap idmap suffix = ou=Idmap,LDAPSUFFIX

# "security = user" is always a good idea. This will require a Unix account
# in this server for every user accessing the server. See
# /usr/share/doc/samba-doc/htmldocs/ServerType.html in the samba-doc
# package for details.
   security = user

# You may wish to use password encryption.  See the section on
# encrypt passwords in the smb.conf(5) manpage before enabling.
   encrypt passwords = true

# If you are using encrypted passwords, Samba will need to know what
# password database type you are using.  
   passdb backend = ldapsam

   obey pam restrictions = yes

;   guest account = nobody
;   invalid users = root

# This boolean parameter controls whether Samba attempts to sync the Unix
# password with the SMB password when the encrypted SMB password in the
# passdb is changed.
   unix password sync = yes

# For Unix password sync to work on a Debian GNU/Linux system, the following
# parameters must be set (thanks to Augustin Luton <aluton@hybrigenics.fr> for
# sending the correct chat script for the passwd program in Debian Potato).
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\sUNIX\spassword:* %n\n *Retype\snew\sUNIX\spassword:* %n\n .

# This boolean controls whether PAM will be used for password changes
# when requested by an SMB client instead of the program listed in
# passwd program. The default is no.
   pam password change = yes


########## Printing ##########

# If you want to automatically load your printer list rather
# than setting them up individually then youll need this
;   load printers = yes

# lpr(ng) printing. You may wish to override the location of the
# printcap file
;   printing = bsd
;   printcap name = /etc/printcap

# CUPS printing.  See also the cupsaddsmb(8) manpage in the
# cupsys-client package.
   printing = cups
   printcap name = cups

# When using [print$], root is implicitly a printer admin, but you can
# also give this right to other users to add drivers and set printer
# properties
;   printer admin = @ntadmin


######## File sharing ########

# Name mangling options
;   preserve case = yes
;   short preserve case = yes


############ Misc ############

# Using the following line enables you to customise your configuration
# on a per machine basis. The %m gets replaced with the netbios name
# of the machine that is connecting
;   include = /home/samba/etc/smb.conf.%m

# Most people will find that this option gives better performance.
# See smb.conf(5) and /usr/share/doc/samba-doc/htmldocs/speed.html
# for details
# You may want to add the following on a Linux system:
#         SO_RCVBUF=8192 SO_SNDBUF=8192
   socket options = TCP_NODELAY

# The following parameter is useful only if you have the linpopup package
# installed. The samba maintainer and the linpopup maintainer are
# working to ease installation and configuration of linpopup and samba.
;   message command = /bin/sh -c /usr/bin/linpopup "%f" "%m" %s; rm %s &

# Domain Master specifies Samba to be the Domain Master Browser. If this
# machine will be configured as a BDC (a secondary logon server), you
# must set this to no; otherwise, the default behavior is recommended.
;   domain master = auto

# Some defaults for winbind (make sure youre not using the ranges
# for something else.)
;   idmap uid = 10000-20000
;   idmap gid = 10000-20000
;   template shell = /bin/bash

#======================= Share Definitions =======================

#En test, vi deler ut /tmp til windowsbrukere:
[share1]
path = /tmp
comment=midlertidige filer
browseable=yes
writeable=yes

[homes]
   comment = Hjemmekataloger
   browseable = no

# By default, the home directories are exported read-only. Change next
# parameter to yes if you want to be able to write to them.
   writable = yes

# File creation mask is set to 0700 for security reasons. If you want to
# create files with group=rw permissions, set next parameter to 0775.
   create mask = 0700

# Directory creation mask is set to 0700 for security reasons. If you want to
# create dirs. with group=rw permissions, set next parameter to 0775.
   directory mask = 0700

# Un-comment the following and create the netlogon directory for Domain Logons
# (you need to configure Samba to act as a domain controller too.)
[netlogon]
   comment = Network Logon Service
   path = /home/samba/netlogon
   guest ok = yes
   writable = no
   share modes = no
   write list = ntadmin

[profiles]
   path=/home/samba/profiles
   read only = no
   create mask = 0600
   directory mask = 0700
   guest ok = Yes
   profile acls = yes
   csc policy = disable
   # next line is a great way to secure the profiles 
   force user = %U 
   # next line allows administrator to access all profiles 
   valid users = %U "Domain Admins"

[printers]
   comment = All Printers
   browseable = no
   path = /tmp
   printable = yes
   public = no
   writable = no
   create mode = 0700

# Windows clients look for this share name as a source of downloadable
# printer drivers
[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
# Uncomment to allow remote administration of Windows print drivers.
# Replace ntadmin with the name of the group your admin users are
# members of.
;   write list = root, @ntadmin

# A sample share for sharing your CD-ROM with others.
;[cdrom]
;   comment = Samba servers CD-ROM
;   writable = no
;   locking = no
;   path = /cdrom
;   public = yes

# The next two parameters show how to auto-mount a CD-ROM when the
#	cdrom share is accesed. For this to work /etc/fstab must contain
#	an entry like this:
#
#       /dev/scd0   /cdrom  iso9660 defaults,noauto,ro,user   0 0
#
# The CD-ROM gets unmounted automatically after the connection to the
#
# If you dont want to use auto-mounting/unmounting make sure the CD
#	is mounted on /cdrom
#
;   preexec = /bin/mount /cdrom
;   postexec = /bin/umount /cdrom' > /etc/samba/smb.conf

sed -i "s/NETBIOS_NAME/"$NETBIOS_NAME"/g" /etc/samba/smb.conf
sed -i "s/SMBDOMENE/"$SMBDOMENE"/g" /etc/samba/smb.conf
sed -i "s/LDAPSUFFIX/"$LDAPSUFFIX"/g" /etc/samba/smb.conf

# Restarter Samba
/etc/init.d/samba restart

LDAPPASSWD=""
SPORSMAL="Skriv inn ldap passordet:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	LDAPPASSWD=BYTTUTMEDENGANG
else
	LDAPPASSWD=$INPUT_LOWER_CASE
fi

# Setter passordet til root
smbpasswd -w $LDAPPASSWD


###########################
# Innstallere smbldap-tools
###########################

apt-get install -qy smbldap-tools

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
slavePw="LDAPPASSWD"
masterDN="cn=admin,LDAPSUFFIX"
masterPw="LDAPPASSWD"' > /etc/smbldap-tools/smbldap_bind.conf

sed -i "s/LDAPSUFFIX/"$LDAPSUFFIX"/g" /etc/smbldap-tools/smbldap_bind.conf
sed -i "s/LDAPPASSWD/"$LDAPPASSWD"/g" /etc/smbldap-tools/smbldap_bind.conf

# sikrer /etc/smbldap-tools/smbldap_bind.conf slik at bare root kan lese denne
chmod 600 /etc/smbldap-tools/smbldap_bind.conf

# Henter inn SID
LOCALSID=`net getlocalsid | mawk '{ print $6 }'`
echo $LOCALSID


# Oppretter /etc/smbldap-tools/smbldap.conf
# Mye hardkodet her også
echo "
##############################################################################
#
# General Configuration
#
##############################################################################

# Put your own SID
# to obtain this number do: net getlocalsid
SID="$LOCALSID"" > /etc/smbldap-tools/smbldap.conf

echo '
##############################################################################
#
# LDAP Configuration
#
##############################################################################

# Notes: to use to dual ldap servers backend for Samba, you must patch
# Samba with the dual-head patch from IDEALX. If not using this patch
# just use the same server for slaveLDAP and masterLDAP.
# Those two servers declarations can also be used when you have 
# . one master LDAP server where all writing operations must be done
# . one slave LDAP server where all reading operations must be done
#   (typically a replication directory)

# Ex: slaveLDAP=127.0.0.1
slaveLDAP="127.0.0.1"
slavePort="389"

# Master LDAP : needed for write operations
# Ex: masterLDAP=127.0.0.1
masterLDAP="127.0.0.1"
masterPort="389"

# Use TLS for LDAP
# If set to 1, this option will use start_tls for connection
# (you should also used the port 389)
ldapTLS="0"

# How to verify the servers certificate (none, optional or require)
# see "man Net::LDAP" in start_tls section for more details
verify="none"

# CA certificate
# see "man Net::LDAP" in start_tls section for more details
cafile="/etc/smbldap-tools/ca.pem"

# certificate to use to connect to the ldap server
# see "man Net::LDAP" in start_tls section for more details
clientcert="/etc/smbldap-tools/smbldap-tools.pem"

# key certificate to use to connect to the ldap server
# see "man Net::LDAP" in start_tls section for more details
clientkey="/etc/smbldap-tools/smbldap-tools.key"

# LDAP Suffix
# Ex: suffix=dc=IDEALX,dc=ORG
suffix="LDAPSUFFIX"

# Where are stored Users
# Ex: usersdn="ou=Users,dc=IDEALX,dc=ORG"
usersdn="ou=People,${suffix}"

# Where are stored Computers
# Ex: computersdn="ou=Computers,dc=IDEALX,dc=ORG"
# Lagres sammen med brukere, ellers får samba problemer med
# å finne dem igjen. . .
computersdn="ou=People,${suffix}"

# Where are stored Groups
# Ex groupsdn="ou=Groups,dc=IDEALX,dc=ORG"
groupsdn="ou=Group,${suffix}"

# Where are stored Idmap entries (used if samba is a domain member server)
# Ex groupsdn="ou=Idmap,dc=IDEALX,dc=ORG"
idmapdn="ou=Idmap,${suffix}"

# Where to store next uidNumber and gidNumber available
# sambaUnixIdPooldn="cn=NextFreeUnixId,${suffix}"
sambaUnixIdPooldn="sambaDomainName=SMBDOMENE,${suffix}"

# Default scope Used
scope="sub"

# Unix password encryption (CRYPT, MD5, SMD5, SSHA, SHA)
hash_encrypt="MD5"

# if hash_encrypt is set to CRYPT, you may set a salt format.
# default is "%s", but many systems will generate MD5 hashed
# passwords if you use "$1$%.8s". This parameter is optional!
crypt_salt_format="%s"

##############################################################################
# 
# Unix Accounts Configuration
# 
##############################################################################

# Login defs
# Default Login Shell
# Ex: userLoginShell="/bin/bash"
userLoginShell="/bin/bash"

# Home directory
# Ex: userHome="/home/%U"
userHome="/home/%U"

# Gecos
userGecos="System User"

# Default User (POSIX and Samba) GID
defaultUserGid="513"

# Default Computer (Samba) GID
defaultComputerGid="515"

# Skel dir
skeletonDir="/etc/skel"

# Default password validation time (time in days) Comment the next line if
# you dont want password to be enable for defaultMaxPasswordAge days (be
# careful to the sambaPwdMustChange attributes value)
defaultMaxPasswordAge="99"

##############################################################################
#
# SAMBA Configuration
#
##############################################################################

# The UNC path to home drives location (%U username substitution)
# Ex: \\My-PDC-netbios-name\homes\%U
# Just set it to a null string if you want to use the smb.conf logon home
# directive and/or disable roaming profiles
userSmbHome="\\NETBIOS_NAME\homes\%U"

# The UNC path to profiles locations (%U username substitution)
# Ex: \\My-PDC-netbios-name\profiles\%U
# Just set it to a null string if you want to use the smb.conf logon path
# directive and/or disable roaming profiles
userProfile="\\NETBIOS_NAME\profiles\%U"

# The default Home Drive Letter mapping
# (will be automatically mapped at logon time if home directory exist)
# Ex: H: for H:
userHomeDrive="H:"

# The default user netlogon script name (%U username substitution)
# if not used, will be automatically username.cmd
# make sure script file is edited under dos
# Ex: %U.cmd
# userScript="startup.cmd" # make sure script file is edited under dos
# Personlige oppstartscript:
# userScript="%U.cmd"
userScript=startup.cmd


# Domain appended to the users "mail"-attribute
# when smbldap-useradd -M is used
mailDomain="aitel.hist.no"

##############################################################################
#
# SMBLDAP-TOOLS Configuration (default are ok for a RedHat)
#
##############################################################################

# Allows not to use smbpasswd (if with_smbpasswd == 0 in smbldap_conf.pm) but
# prefer Crypt::SmbHash library
with_smbpasswd="0"
smbpasswd="/usr/bin/smbpasswd"' >> /etc/smbldap-tools/smbldap.conf

sed -i "s/LDAPSUFFIX/"$LDAPSUFFIX"/g" /etc/smbldap-tools/smbldap.conf
sed -i "s/SMBDOMENE/"$SMBDOMENE"/g" /etc/smbldap-tools/smbldap.conf
sed -i "s/NETBIOS_NAME/"$NETBIOS_NAME"/g" /etc/smbldap-tools/smbldap.conf


# Restarter Samba
/etc/init.d/samba restart

# Restarter ldap daemon
/etc/init.d/slapd restart

# Henter ut systemkonoter og legger dem i en ldif fil
smbldap-populate -e populate.ldif

# Importerer systemkontoene inn i ldap db
smbldap-populate

# testbruker fjerner før ver 1.0
smbldap-useradd -a ole

# setter passord på testbruker, fjernes før ver 1.0
smbldap-passwd -a ole
