#!/bin/bash 

## 
# Skript som installerer en del pakker som det er praktisk å ha
# før selve installasjonene av ulike tjenster.
##

apt-get install openssh-server sudo htop screen openssl quota quotatool acl vim 
echo "Husk å slå av muligheten til å logge inn som root etter at
sudo er konfigurert ---> /etc/ssh/sshd_config"

