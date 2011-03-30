#!/bin/bash

#
# Installasjonsscript for sette opp dual homed maskin
# som gateway, med nat'ing og forwarding
#
## Rev. 0.2beta (1.0 er det samme som fult operativ)
# -------------
# 0.1 Skjelettet opprettet. Ingen ting lagt til ennå. 
# Lagt til sjekk om det er nett på maskinen. Ingen grunn til å kjøre i gang
# installasjoner uten nett.
# Må få oversikt over nødvendige variabler til konfigurasjonen.
# 0.2 Fullført til betatesting
# -------------
# Last edit: Sat 26 Mar 2011
#
# TODO:
# 1. Legge til disabling av ipv6
# 2. Sperre for ipv6 i iptables
##

# Oppretter startup script og legger dette til slilk at det starter opp
# ved boot

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

################
# ACTION
################

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
	sed -i '14/#/d' /etc/init.d/fw-script.sh

else
	echo "Du har valgt å ikke implementere SQUID i brannmuren nå"
fi





# Disable ipv6 slik at nettverksinterfacen ikke starter opp med dette

