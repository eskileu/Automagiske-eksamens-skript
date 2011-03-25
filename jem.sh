#!/bin/bash

core=core.schema
cosine=cosine.schema
nis=nis.schema
inet=inetorgperson.schema

test=`grep -q -e $core -e $cosine -e $nis -e $inet /etc/ldap/slapd.conf | wc -l`

if  [ test -eq 4 ]; then
	echo "good to go"
else 
	echo "dust"
fi


