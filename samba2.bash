#!/bin/bash

apt-get install samba samba-doc

apt-get install smbclient

mkdir /home/delt

###############################
# lager ny /etc/samba/smb.conf
###############################

rm /etc/samba/smb.conf


echo '
#======================= Global Settings =======================

[global]

## Browsing/Identification ###

# Change this to the workgroup/NT-domain name your Samba server will part of
   workgroup = deadbits

#  Maskinnavnet som jeg satte på Linux-en som kjører Sambaen
   netbios name = deadbits
   server string = atlas
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
   add machine script = /usr/sbin/useradd -s /bin/false -d /dev/null -g maskiner '%u'

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

##################################
# avslutt smb.conf
##################################

mkdir -m 0755 /var/lib/samba/netlogon

echo 'net use w: \\deadbits\samba-share /P:No /yes' > /var/lib/samba/netlogon/netlogon.bat

# root passord 2 ganger
echo "Sett root passord for root:"
smbpasswd -a

# Legge til en gruppe for maskiner (undersøke om dette er nødvendig)
groupadd maskiner
useradd -g maskiner -d /dev/null -s /bin/false winxp\$
smbpasswd -a -m winxp

apt-get install smbldap-tools

cp /usr/share/doc/samba-doc/examples/LDAP/samba.schema.gz /etc/ldap/schema/

gunzip /etc/ldap/schema/samba.schema.gz

sed -i '14 a\include        /etc/ldap/schema/samba.schema' /etc/ldap/slapd.conf

/etc/init.d/slapd restart

echo '
# Her kommer LDAP-tingene
ldap suffix = deadbits,dc=localdomain
ldap user suffix = ou=People
ldap group suffix = ou=Group
ldap machine suffix = ou=People
ldap idmap suffix = ou=Idmap
ldap passwd sync = yes
ldap admin dn = cn=admin,dc=deadbits,dc=localdomain

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
set primary group script = /usr/sbin/smbldap-usermod -g "%g" "%u"' >> /etc/samba/smb.conf

/etc/init.d/samba restart

PASSORD=`echo ldap admin passord`
smbpasswd -w $PASSORD

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
slaveDN="cn=admin,dc=deadbits,dc=localdomain"
slavePw="1234"
masterDN="cn=admin,dc=deadbits,dc=localdomain"
masterPw="1234"' > /etc/smbldap-tools/smbldap_bind.conf

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
suffix="dc=deadbits,dc=localdomain"

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
userSmbHome="\\deadbits\homes\%U"

# The UNC path to profiles locations (%U username substitution)
userProfile="\\deadbits\profiles\%U"

# The default Home Drive Letter mapping
userHomeDrive="H:"

# The default user netlogon script name (%U username substitution)
userScript=startup.cmd

# Domain appended to the users "mail"-attribute
mailDomain="deadbits.localdomain"

# SMBLDAP-TOOLS Configuration (default are ok for a RedHat)

# Allows not to use smbpasswd
smbpasswd="/usr/bin/smbpasswd"' >> /etc/smbldap-tools/smbldap.conf



# setter passord på bruker
smbpasswd -U janmag
# tester klient oppsett
smbclient -U janmag -L localhost



