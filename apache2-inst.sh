#!/bin/bash 

## 
# Automatisert apache mysql phpmyadmin phpldapadmin
# Rev. 0.3 (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# 0.2 Klar for testing.
# 0.3 Wordpress lagt til med database oppretting. Må testes
# -------------
# Last edit: Sun 27 Mar 2011
#
# TODO:
#
##


#################################################
# UNDER DETTE SKILLET SKAL KUN FUNKSJONER LIGGE 
# FUNKSJONER MÅ VIST LESES FØRST...             
#################################################

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

##################################################
# UNDER DETTE SKILLET KJØRER VI NOEN ENKLE TESTER
##################################################

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
if ping -c 1 158.38.48.10 > /dev/null; then
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

#####################################################
# UNDER DETTE SKILLET SKAL DEN UTFØRENDE KODEN LIGGE
#####################################################


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