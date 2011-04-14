#!/bin/bash 

## 
# Eksperimentel kode som kanskje har en fremtid.
# En del av experiment branchen til automagiske
# skript til eksamen. Skilt ut for at de
# ikke skal kludre til master branch. Merges inn
# i master når ting er testet godt nok
##



# Funksjon hentet fra: 
# http://www.linuxquestions.org/questions/programming-9/bash-cidr-calculator-646701/
# Ingen vits å finne opp kruttet på nytt :)
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
}
