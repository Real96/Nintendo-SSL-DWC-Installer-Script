#!/bin/sh

sleep 15  # sleep is needed to avoid dnsmasq to try loading interfaces too early at boot
service nginx restart
service dnsmasq restart
cd /var/www/dwc_network_server_emulator/
python2.7 master_server.py