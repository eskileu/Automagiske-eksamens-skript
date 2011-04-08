#!/bin/bash

#
# Skript for å samle de ulike installasjonene.
# Tilbyr en dialog hvor brukere kan velge hva de vil kjøre
#
## Rev. 0.09 (1.0 er det samme som fult operativ)
# -------------
# 0.01 Startet på grunn strukturen.
# 0.02 Lagt til gateway installasjonen
# 0.03 Lagt til DNS og testet den alene
# 0.04 Lagt til DHCP og testet den alene
# 0.05 Lagt til EPOST, ikke testet ennå
# 0.09 Lagt til BackupPC, SQUID og LAMP, men ingen testet.
# -------------
# Last edit: Fri 8 Apr 2011
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

############################
#   -*-Input funksjon-*-   #
# Hentet fra Tihlde Drift  #     
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
		read -t 120 INPUT <&1

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
function instGateway(){
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

#----DNS----#
function instDNS(){

IP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`

apt-get install -q -y bind9 bind9-doc resolvconf

# Rekonfigurere /etc/bind/named.conf.local

SPORSMAL="Skriv inn domenenavn:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
        DOMAIN=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
        DOMAIN=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn ip-nettadresse (0.168.192):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
        IPREV=`echo 1000000`
else
        IPREV=$INPUT_LOWER_CASE
fi

echo '
zone "DOMAIN" {  
        type master;
        file "/etc/bind/db.DOMAIN";
};
zone "IPREV.in-addr.arpa" {
        type master;
        notify no;
        file "/etc/bind/db.IPREV";
};' >> /etc/bind/named.conf.local
sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/bind/named.conf.local
sed -i "s/IPREV/"$IPREV"/g" /etc/bind/named.conf.local

# Lager innslagsfilene for domenet vårt

IP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`

touch /etc/bind/db.$DOMAIN 
touch /etc/bind/db.$IPREV


echo '
; BIND data fil for lokal loopback
;

$TTL    604800

@       IN      SOA     ns.DOMAIN. root.DOMAIN. (
                        1               ;Serial
                        604800          ;Refresh
                        86400           ;Retry
                        2419200         ;Expire
                        604800          ;Default TTL
)

@       IN      NS      ns.DOMAIN.
ns      IN      A       IP
box     IN      A       IP' >> /etc/bind/db.$DOMAIN

sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/bind/db.$DOMAIN
sed -i "s/IP/"$IP"/g" /etc/bind/db.$DOMAIN

echo '
;
; BIND reverse data fil for lokal loopback
;
$ORIGIN	DOMAIN.
$TTL    604800
@       IN      SOA     ns.DOMAIN. (
                        2       ;Serienummer
                        604800  ;Refresh
                        86400   ;Retry
                        2419200 ;Expire
                        604800) ;Negative Cache TTL
;
@       IN      NS      ns.
93      IN      PTR     ns.DOMAIN.' >> /etc/bind/db.$IPREV

sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/bind/db.$IPREV
sed -i "s/IP/"$IP"/g" /etc/bind/db.$IPREV

# Vi tester innstallasjonen

named-checkzone $DOMAIN /etc/bind/db.$DOMAIN

/etc/init.d/bind9 restart

} # Slutt DNS


#----DHCP----#
function instDHCP(){
apt-get install -q -y dhcp3-server

rm /etc/dhcp3/dhcpd.conf
touch /etc/dhcp3/dhcpd.conf

echo '
# DHCP konfigurasjon for lokalt nett

ddns-update-style none;

# setter en default for domene navn og navnetjener
option domain-name "DOMAIN";
option domain-name-servers DNSOTHER;

# Lease tid
default-lease-time 600;
max-lease-time 7200;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
log-facility local7;

subnet SUBNET netmask NETMASK {
        range RANGE_START RANGE_STOP;
        option routers ROUTER_IP;
}' >> /etc/dhcp3/dhcpd.conf

# Domenenavn
SPORSMAL="Skriv inn domenenavn:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DOMAIN=`cat /etc/hosts | grep 127.0.1.1 | awk '{ print $2 }'`
else
	DOMAIN=$INPUT_LOWER_CASE
fi

# DNS ip-adress
# Her må det testes hvilken adresse vi kan bruke
SPORSMAL="Skriv inn ip til autorativ dns-tjener, forutsetter at internt nett er på eth1:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DNSOTHER=`/sbin/ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`
else
	DNSOTHER=$INPUT_LOWER_CASE
fi

# Her setter vi subnettet
SPORSMAL="Skriv inn subnett:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	SUBNET=0.0.0.0
else
	SUBNET=$INPUT_LOWER_CASE
fi

# Her setter vi nettmaska
SPORSMAL="Skriv inn nettmasken (ENTER: default 255.255.255.0):"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	NETMASK=255.255.255.0
else
	NETMASK=$INPUT_LOWER_CASE
fi

# Her setter vi startip
SPORSMAL="Skriv inn første ip:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	RANGE_START=0.0.0.0
else
	RANGE_START=$INPUT_LOWER_CASE
fi

# Her setter vi stoppip
SPORSMAL="Skriv inn siste ip:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	RANGE_STOP=0.0.0.0
else
	RANGE_STOP=$INPUT_LOWER_CASE
fi

# Her setter vi ip-addressen til ruteren
SPORSMAL="Skriv inn ruter ip:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	ROUTER_IP=0.0.0.0
else
	ROUTER_IP=$INPUT_LOWER_CASE
fi

sed -i "s/DOMAIN/"$DOMAIN"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/DNSOTHER/"$DNSOTHER"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/SUBNET/"$SUBNET"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/NETMASK/"$NETMASK"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/RANGE_START/"$RANGE_START"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/RANGE_STOP/"$RANGE_STOP"/g" /etc/dhcp3/dhcpd.conf
sed -i "s/ROUTER_IP/"$ROUTER_IP"/g" /etc/dhcp3/dhcpd.conf

/etc/init.d/dhcp3-server restart
} # Slutt DHCP

#----SAMDAP----#
function instSAMDAP(){
 echo "DUMMY INPUT"
} #Slutt SAMDAP

#----LAMP----#
function instLAMP(){
##
# Variablelkassen. Kom med innspill her på hvilke verdier som vi trenger.
##

# Konfig variabler
NETT_I_CIDR="" # Denne MÅ vi ha
MYSQLROOTPASS=""

SPORSMAL="Angi LAN med CIDR notasjon (192.168.10.0/24) "
getInput 1
NETT_I_CIDR=$INPUT

SPORSMAL="Skriv inn ønsket rootpassord for mysql: "
getInput 1
MYSQLROOTPASS=$INPUT


#########
# MYSQL #
#########
apt-get install -qy mysql-server

##########
# APACHE #
##########
apt-get install -qy apache2 apache2-mpm-prefork
apt-get install -qy php5

# Aktiver støtte for https sider. Better safe then sorry :)
a2enmod ssl
a2ensite default-ssl
a2enmod userdir
mkdir /etc/skel/public_html
cd /etc/ssl/private
make-ssl-cert generate-default-snakeoil

##############
# PHPMYADMIN #
##############
apt-get install -qy phpmyadmin

# Vi vil tvinge folk over på https og det skal 
# kun være mulig å nå den om man sitter internt
a2enmod rewrite
echo "
Alias /pma /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
        Options Indexes FollowSymLinks
        DirectoryIndex index.php
        AllowOverride All
        Order deny,allow

        <IfModule mod_php5.c>
                AddType application/x-httpd-php .php

                php_flag magic_quotes_gpc Off
                php_flag track_vars On
                php_flag register_globals Off
                php_value include_path .
        </IfModule>

        # Blokker alle eksterne tilkoblinger
        Deny from all

        # Aapne for lokale tilkoblinger
        Allow from 127.0.0.1
        Allow from ${NETT_I_CIDR}

        # Tving alle tilkoblinger over paa https
        RewriteEngine on
        RewriteCond %{HTTPS} off
        RewriteRule ^(.*)$ https://%{HTTP_HOST}/pma/ [R]
</Directory>" > /etc/phpmyadmin/apache.conf

################
# PHPLDAPADMIN #
################
apt-get install -qy phpldapadmin

echo "
<IfModule mod_alias.c>
    Alias /pla /usr/share/phpldapadmin/htdocs
</IfModule>

<Directory /usr/share/phpldapadmin/htdocs/>

    DirectoryIndex index.php
    Options +FollowSymLinks
    AllowOverride All

    Order deny,allow
    Deny from all

    # Aapne for lokale tilkoblinger
    Allow from 127.0.0.1
    Allow from ${NETT_I_CIDR}

    <IfModule mod_mime.c>

      <IfModule mod_php5.c>
        AddType application/x-httpd-php .php

        php_flag magic_quotes_gpc Off
        php_flag track_vars On
        php_flag register_globals On
        php_value include_path .
      </IfModule>

      <IfModule !mod_php5.c>
        <IfModule mod_actions.c>
          <IfModule mod_cgi.c>
            AddType application/x-httpd-php .php
            Action application/x-httpd-php /cgi-bin/php5
          </IfModule>
          <IfModule mod_cgid.c>
            AddType application/x-httpd-php .php
            Action application/x-httpd-php /cgi-bin/php5
           </IfModule>
        </IfModule>
      </IfModule>

    </IfModule>
    # Tving alle tilkoblinger over paa https
    RewriteEngine on
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}/pla/ [R]
</Directory>" > /etc/phpldapadmin/apache.conf

#############
# WORDPRESS #
#############
cd /var/www ..
wget http://wordpress.org/latest.tar.gz
tar xvfz latest.tar.gz
rm latest.tar.gz
mv wordpress blog

/etc/init.d/apache2 restart

CREATEDB="CREATE DATABASE wordpress;"
WPDBUSER="GRANT ALL PRIVILEGES ON wordpress.* TO wordpress@localhost IDENTIFIED BY 'asdfg1234N';"
DBSKYLL="FLUSH PRIVILEGES;"

mysql -u root --password=$MYSQLROOTPASS -e "$CREATEDB"
mysql -u root --password=$MYSQLROOTPASS -e "$WPDBUSER"
mysql -u root --password=$MYSQLROOTPASS -e "$DBSKYLL"

echo "

${REDTEMP}URL OVERSIKT${RESETTEMP}
phpldapadmin ----->  https://FQDN/pla (kun internt)
phpmyadmin   ----->  https://FQDN/pma (kun internt)

Wordpress er lastet ned, men installasjonen er ikke fullført!
wordpress    ----->  http://FQDN/blog/wp-admin/install.php
				     Databasenavn ---> wordpress
				     DBbruker     ---> wordpress
				     DBpassord    ---> asdfg1234N
				     hostvalg     ---> localhost
				
"
} #Slutt LAMP

#----SQUID----#
function instSQUID(){
##
# Variablelkassen. Kom med innspill her på hvilke verdier som vi trenger.
##

# Konfig variabler
INTERNIP=""
PORT=""
NETTMASKE=""
CIDR=""


SPORSMAL="Hva er IP adressen skal squid benytte? "
getInput 1
INTERNIP=$INPUT

SPORSMAL="Hvilken port vil du at squid skal bruke? "
getInput 1
PORT=$INPUT

SPORSMAL="Hva er nettmasken som skal benyttes? "
getInput 1
NETTMASKE=$INPUT

SPORSMAL="Skriv inn din nettadresse med CIDR notasjon (192.168.145.0/24): "
getInput 1
CIDR=$INPUT


##
# Installasjon av squid3
##
apt-get install -qy squid3

mkdir /etc/squid3/acl
cd /etc/squid3/acl
touch denied_ads.acl denied_domains.acl denied_filetypes.acl

##
# Fyll acl filer med test innhold
##
echo '.vg.no
.sex.com
.hackers.com
.xemacs.org
.stormtroopers.no' > /etc/squid3/acl/denied_domains.acl

echo '/adv/.*\.gif$
/[Aa]ds/.*\.gif$
/[Aa]d[Pp]ix/
/[Aa]d[Ss]erver
/[Aa][Dd]/.*\.[GgJj][IiPp][FfGg]$
/[Bb]annerads/' > /etc/squid3/acl/denied_ads.acl

echo '\.(exe)$
\.(zip)$
\.(mp3)$
\.(avi)$' > /etc/squid3/acl/denied_filetypes.acl

##
# Konfigurasjon squid3
##
mv /etc/squid3/squid.conf /etc/squid3/squid.conf.old

echo "http_port $INTERNIP:$PORT transparent
client_netmask $NETTMASKE
http_port $PORT transparent
acl our_networks src $CIDR
acl localnet src 127.0.0.1/255.255.255.255" > /etc/squid3/squid.conf

echo '
acl denied_domains dstdomain "/etc/squid3/acl/denied_domains.acl"
acl filetypes urlpath_regex -i "/etc/squid3/acl/denied_filetypes.acl"
acl url_ads url_regex "/etc/squid3/acl/denied_ads.acl"

http_access deny denied_domains
http_access deny filetypes
http_access deny url_ads
http_access allow our_networks
http_access allow localnet
cache_mem 100 MB
cache_dir ufs /var/spool/squid3 300 16 256
access_log /var/log/squid3/access.log squid
coredump_dir /var/spool/squid3' >> /etc/squid3/squid.conf

# Restart av squid3
/etc/init.d/squid3 restart

echo '
Ferdig!!
Du må fortsatt sette iptables regelen. (Eskil vi setter den i gateway scriptet, eller? :)) (OK, Jan Egil)
Eksempel:
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j REDIRECT --to ${INTERNIP}.${PORT}
'
} #Slutt SQUID

#----EPOST----#
function instEPOST(){
##
# Variablelkassen. Kom med innspill her på hvilke verdier som vi trenger.
##

# Konfig variabler
HOSTNAVN="" # Denne MÅ vi ha
DOMENE=""   # Denne MÅ vi ha
HOSTIP=""   # Denne MÅ vi ha
EKSTERNT_INTERFACE="" # Om noen skulle bruke noe annet en eth0

SPORSMAL="Hvilken hostname har serveren: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	HOSTNAVN=`hostname`
else
	HOSTNAVN=$INPUT_LOWER_CASE
fi

SPORSMAL="Hvilket domene skal serveren benytte: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	DOMENE=`hostname -d`
else
	DOMENE=$INPUT_LOWER_CASE
fi

SPORSMAL="Hvilket interface er det eksterne: "
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	EKSTERNT_INTERFACE="eth0"
else
	EKSTERNT_INTERFACE=$INPUT_LOWER_CASE
fi

SPORSMAL="Skriv inn serveren sin eksterne IP adresse:"
getInput 1
if [ -z $INPUT_LOWER_CASE ]; then
	HOSTIP=`ifconfig $EKSTERNT_INTERFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
else
	HOSTIP=$INPUT_LOWER_CASE
fi


###################
# POSTFIX OG SASL #
###################
echo " "
echo "STARTER INSTALLASJON AV POSTFIX"
echo " "
apt-get update
apt-get -qy install postfix sasl2-bin procmail libsasl2-modules

postconf -e 'smtpd_sasl_local_domain ='
postconf -e 'smtpd_sasl_auth_enable = yes'
postconf -e 'smtpd_sasl_security_options = noanonymous'
postconf -e 'broken_sasl_auth_clients = yes'
postconf -e 'smtpd_sasl_authenticated_header = yes'
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination'
postconf -e 'inet_interfaces = all'

touch /etc/postfix/sasl/smtpd.conf
echo 'pwcheck_method: saslauthd' >> /etc/postfix/sasl/smtpd.conf
echo 'mech_list: plain login' >> /etc/postfix/sasl/smtpd.conf

# Fiks av rettigheter mellom sasl og postfix
rm -r /var/run/saslauthd/
mkdir -p /var/spool/postfix/var/run/saslauthd
ln -s /var/spool/postfix/var/run/saslauthd /var/run
chgrp sasl /var/spool/postfix/var/run/saslauthd
adduser postfix sasl

# Opprette ssl nøkler til postfix
mkdir /etc/postfix/ssl
cd /etc/postfix/ssl/
echo "${REDTEMP}OBS!${RESETTEMP} smtpd og pem passordene må har 4 tegn eller mer!!"
openssl genrsa -des3 -rand /etc/hosts -out smtpd.key 1024
chmod 600 smtpd.key
openssl req -new -key smtpd.key -out smtpd.csr
openssl x509 -req -days 3650 -in smtpd.csr -signkey smtpd.key -out smtpd.crt
openssl rsa -in smtpd.key -out smtpd.key.unencrypted
mv -f smtpd.key.unencrypted smtpd.key
openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650

postconf -e "myhostname = $HOSTNAVN.$DOMENE"
postconf -e 'smtpd_tls_auth_only = no'
postconf -e 'smtp_use_tls = yes'
postconf -e 'smtpd_use_tls = yes'
postconf -e 'smtp_tls_note_starttls_offer = yes'
postconf -e 'smtpd_tls_key_file = /etc/postfix/ssl/smtpd.key'
postconf -e 'smtpd_tls_cert_file = /etc/postfix/ssl/smtpd.crt'
postconf -e 'smtpd_tls_CAfile = /etc/postfix/ssl/cacert.pem'
postconf -e 'smtpd_tls_loglevel = 1'
postconf -e 'smtpd_tls_received_header = yes'
postconf -e 'smtpd_tls_session_cache_timeout = 3600s'
postconf -e 'tls_random_source = dev:/dev/urandom'

mkdir -p /var/spool/postfix/var/run/saslauthd
sed -i '/START=no/ c\START=yes' /etc/default/saslauthd
sed -i 's|"-c -m /var/run/saslauthd"|"-c -m /var/spool/postfix/var/run/saslauthd"|g' /etc/default/saslauthd

# Restart sasl og postfix
/etc/init.d/postfix restart
/etc/init.d/saslauthd restart

### Legg inn varsling om telnet test og en mulighet til å avbryte om noe skulle være feil
## tekstsnutt som forklarer telnet bruk og etter test en pause hvor vi git muligheten til å avbryte

echo "
STEG 1 FERDIG!
Gjennomfør en telnet test for å sjekke at postfix er tilgjengelig.
Ta en ${LIGHTCYANTEMP}ehlo localhost${RESETTEMP} i telnet. Se etter AUTH PLAIN
og TLS.
"
telnet localhost 25
pause "Om alt ser ut til å være korrekt trykk ENTER. Avbryt eventuelt med CTRL+C"

###########
# COURIER #
###########
echo "
START COURIER INNSTALLASJON OG KONFIGURASJON
"
apt-get install -qy courier-authdaemon courier-base courier-imap courier-imap-ssl courier-pop courier-pop-ssl courier-ssl gamin libgamin0 libglib2.0-0

###########
# CLAMAV  #
###########
echo "
START CLAMAV INNSTALLASJON OG KONFIGURASJON
"
apt-get install -qy clamav clamav-docs clamav-daemon clamav-freshclam
apt-get install -qy arc arj bzip2 cabextract lzop nomarch p7zip pax tnef unrar-free unzip zoo ripole
echo "deb http://ftp.no.debian.org/debian/ lenny non-free" >> /etc/apt/sources.list
apt-get install -qy lha unrar
apt-get install -qy clamav-testfiles
clamscan /usr/share/clamav-testfiles
clamdscan /usr/share/clamav-testfiles/
apt-get remove -qy clamav-testfiles

#################
# SPAMASSASSIN  #
#################
echo "
START SPAMASSASSIN INNSTALLASJON OG KONFIGURASJON
"
apt-get install -qy spamassassin spamc
apt-get install -qy razor pyzor

sed -i '/ENABLED=0/ c\ENABLED=1' /etc/default/spamassassin
sed -i '/CRON=0/ c\CRON=1' /etc/default/spamassassin

/etc/init.d/spamassassin restart

###########
# AMAVIS  #
###########
apt-get install -qy amavisd-new
echo '
##
# Amavis (A mail virus scanner)
##
content_filter = amavis:[127.0.0.1]:10024
receive_override_options = no_address_mappings' >> /etc/postfix/main.cf

echo '
#
# amavisd-new scanner
#
amavis unix - - - - 2 smtp
        -o smtp_data_done_timeout=1200
        -o smtp_send_xforward_command=yes
        -o disable_dns_lookups=yes
        -o max_use=20
        -o smtp_generic_maps=

127.0.0.1:10025 inet n - - - - smtpd
        -o content_filter=
        -o smtpd_delay_reject=no
        -o smtpd_client_restrictions=permit_mynetworks,reject
        -o smtpd_helo_restrictions=
        -o smtpd_sender_restrictions=
        -o smtpd_recipient_restrictions=permit_mynetworks,reject
        -o smtpd_end_of_data_restrictions=
        -o smtpd_restriction_classes=
        -o mynetworks=127.0.0.0/8
        -o smtpd_error_sleep_time=0
        -o smtpd_soft_error_limit=1001
        -o smtpd_hard_error_limit=1000
        -o smtpd_client_connection_count_limit=0
        -o smtpd_client_connection_rate_limit=0
        -o receive_override_options=no_header_body_checks,no_unknown_recipient_checks
        -o local_header_rewrite_clients=
        -o local_recipient_maps=
        -o relay_recipient_maps=
        -o strict_rfc821_envelopes=yes' >> /etc/postfix/master.cf

/etc/init.d/postfix restart
		

######################################
# CLAMAV OG SPAMASSASSIN INTEGRASJON #
######################################
adduser clamav amavis
adduser amavis clamav

echo '
use strict;
@bypass_virus_checks_maps = (
   \%bypass_virus_checks, \@bypass_virus_checks_acl, \$bypass_virus_checks_re);

@bypass_spam_checks_maps = (
   \%bypass_spam_checks, \@bypass_spam_checks_acl, \$bypass_spam_checks_re);

1;  # ensure a defined return' > /etc/amavis/conf.d/15-content_filter_mode

echo -e '
use strict;
$sa_spam_subject_tag = \047***SPAM***\047;
$sa_tag_level_deflt  = undef;  # add spam info headers if at, or above that level
$sa_tag2_level_deflt = 7;      # add spam detected headers at that level
$sa_kill_level_deflt = 30;     # triggers spam evasive actions

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return' > /etc/amavis/conf.d/50-user

/etc/init.d/amavis restart


##############################
# POSTGREY OG POLICYD-WEIGHT #
##############################
apt-get install -qy postgrey policyd-weight
postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination,reject_non_fqdn_recipient,check_policy_service inet:127.0.0.1:60000,check_policy_service inet:127.0.0.1:12525'


########################
# BRUKER KONFIGURASJON #
########################
maildirmake /etc/skel/Maildir
maildirmake -f spam /etc/skel/Maildir

mkdir /etc/skel/.procmail
touch /etc/skel/.procmailrc /etc/skel/.procmail/log
echo '
PATH=/bin:/usr/bin:/local/bin
MAILDIR=$HOME
LOCKMAIL=$HOME/.lockfile
DEFAULT=$HOME/Mailbox
PMDIR=$HOME/.procmail
LOGFILE=$PMDIR/log
MAILFOLDER=$HOME/Maildir/

# Sender spam med 2-sifrede hits til spam mappen
:0:
* ^X-Spam-Status:.Yes, score=[0-9][0-9]
$MAILFOLDER/.spam/

# Resten til spam-mappe
:0:
* ^X-Spam-Status:.Yes,.*
$MAILFOLDER/.spam/

# Ufiltrert epost til Inbox
:0
$MAILFOLDER/' > /etc/skel/.procmailrc

mkdir -m 700 /etc/skel/.spamassassin


########################
# RESTART AV TJENESTER #
########################
/etc/init.d/postfix restart
/etc/init.d/amavis restart
/etc/init.d/clamav-daemon restart
/etc/init.d/courier-authdaemon restart
/etc/init.d/courier-imap restart
/etc/init.d/courier-pop restart
/etc/init.d/courier-imap-ssl restart
/etc/init.d/courier-pop-ssl restart
/etc/init.d/postgrey restart
/etc/init.d/spamassassin restart

echo "

FERDIG!
Ha en fortsatt fin dag :)

"
} #Slutt EPOST

#----BPC----#
function instBPC(){
#############
# ACTION!
#############

HTPASSWD=`echo "Skriv inn htpasswd for brukeren backuppc"`

echo "Du trenger følgende informasjon klar:
- Domenenavn"

# installerer pakkene vi trenger
apt-get install -qy backuppc rsync libfile-rsyncp-perl par2 smbfs

echo "Lager et htpasswd for brukeren backupp"
htpasswd /etc/backuppc/htpasswd backuppc

echo "Lag passord for brukeren backuppc"
passwd backuppc

# Lager sertifikater
echo "Vi logger inn med backuppc bruker. Skriv inn følgende etter at du får shell prompt:
ssh-keygen -t rsa
Deretter kan du exit det shellet og du er ferdig."

su backuppc

IPKLIENT=`Skriv inn ip-adressen til klienten:`
scp /var/lib/backuppc/.ssh/id_rsa.pub $IPKLIENT:/root/.ssh/authorized_keys2

exit

} #Slutt BPC

TMPFIL="/tmp/`date +%N`.tmp"
touch $TMPFIL
INNHOLD=false

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
                        #echo "GATE valgt"
                        instGateway
                elif [ "$line" == "DNS" ]; then
                        #echo "DNS valgt"
                        instDNS
                elif [ "$line" == "DHCP" ]; then
                        #echo "DHCP valgt"
                        instDHCP
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

echo "Filene som ble opprettet finner du her: $TMPFIL"






