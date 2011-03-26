#!/bin/bash

# Samba

apt-get install -q -y samba samba-doc

apt-get install -q -y smbclient

mkdir /usr/delt

rm /etc/samba/smb.conf
touch /etc/samba/smb.conf

echo '
#======================= Global Settings =======================

[global]

## Browsing/Identification ###

# Change this to the workgroup/NT-domain name your Samba server will part of
   workgroup = <ditt_domene>

#  Maskinnavnet som jeg satte på Linux-en som kjører Sambaen
   netbios name = <server_navn_netbios>
   server string = <kommentar som vises>
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
   path = /usr/delt
   public = yes
   writable = no


[homes]
   comment = Home Directories

# Brukerne vil automatisk få montert opp sine hjemmemapper.
# valid users angir hvilke brukere som har tilgang.
   valid users = %S
   browseable = no
   writable = yes' >> /etc/samba/smb.conf


sudo smbpasswd -U <brukernavn>

smbclient -U <brukenavn> -L localhost


