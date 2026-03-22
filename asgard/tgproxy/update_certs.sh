#!/bin/bash

for d in /etc/letsencrypt/live/*/; do
    domain=`basename $d`
    cat $d/fullchain.pem $d/privkey.pem > /opt/asgard/certs/$domain.pem
done

