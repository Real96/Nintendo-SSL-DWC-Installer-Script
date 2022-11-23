#!/bin/bash

# Fix rm error
shopt -s extglob

# Set Linux version variable
. /etc/os-release
version="$NAME $VERSION_ID"

function checkOSVersion() {
	if [[ "$NAME" == "Ubuntu" && $VERSION_ID < 14 ]] || [[ "$NAME" == "Debian GNU/Linux" && $VERSION_ID < 9 ]] ||
		[[ "$NAME" != "Ubuntu" && "$NAME" != "Debian GNU/Linux" ]];
	then
		echo "This Linux distro is not currently supported!"
		echo "Supported distro: Ubuntu 14+ or Debian 9+"

		exit 1
	fi
}

# Check if "00000011.app" file exists
function checkCertFile() {
	if [ ! -f "00000011.app" ]; then
		echo "Unable to find \"00000011.app\" NAND file!"
		echo "Be sure to put it in the same path of the script"
		echo

		exit 1
	fi
}

# Check root privileges and force them in case
function checkSudo() {
	if [ "$(id -u)" != "0" ]; then
		exec sudo "$0"
	fi
}

# Check if all the needed sources sites are reachable
function checkSources() {
	echo "Checking if all sources are reachable..."

	if ping -c 2 github.com >/dev/nul && ping -c 2 www.openssl.org >/dev/nul &&
		ping -c 2 www.nginx.com >/dev/nul && ping -c 2 bootstrap.pypa.io >/dev/nul;
	then
		echo "All needed sources are reachable!"
	else
		echo "Unable to reach all the needed sources!"

		exit 1
	fi

	echo
}

# Install pip
function getPip() {
	wget https://bootstrap.pypa.io/pip/2.7/get-pip.py
	chmod 777 get-pip.py
	python2.7 get-pip.py
	rm get-pip.py
}

# Install all required packages
function getPackages() {
	echo "Installing required packages..."
	dpkg --configure -a  # Fix possible dpkg errors
	apt-get update
	apt-get install make gcc python2.7 dnsmasq git net-tools wget curl -y

	if [ "$version" == "Ubuntu 20.04" ] || [ "$version" == "Ubuntu 22.04" ] ||
		[ "$version" == "Debian GNU/Linux 11" ];
	then
		getPip
		pip install twisted
	else
		apt-get install python-twisted -y
	fi

	echo
}

# Extract Nintendo-signed client certificate files from "00000011.app" file
function extractCertificateFiles() {
	echo "Extracting certificate files from \"00000011.app\"..."
	mkdir -p /var/www/ssl/
	cp 00000011.app /var/www/ssl/
	cd /var/www/ssl/
	wget https://github.com/Real96/Wii_extract_certs/releases/download/linux/extract_certs
	chmod 777 extract_certs
	./extract_certs 00000011.app
	rm !("clientca.pem"|"clientcakey.pem")
	echo
}

# Forge fake Nintendo-signed certificate files
function forgeCertificateFiles() {
	echo "Forging fake certificate files..."
	openssl rsa -inform der -in clientcakey.pem -out NWC.key
	openssl x509 -inform der -in clientca.pem -out NWC.crt
	openssl genrsa -out server.key 1024
	openssl req -new -key server.key -out server.csr <<EOF
EU
Italy
Rome
Nintendo of Italy Inc.
.
*.nintendowifi.net
ro@nintendo.net
.
.
EOF
	openssl x509 -req -in server.csr -CA NWC.crt -CAkey NWC.key -out server.crt -days 7305 -sha1
	cat server.crt NWC.crt > server-chain.crt
	rm !("server.key"|"server-chain.crt")
	echo
}

# Enable weak ciphers in openssl conf file
function setOpnesslConf() {
	sed -i '1iopenssl_conf = default_conf' /usr/local/ssl/openssl.cnf  # Write at the beginning of openssl.cnf
	cat >> /usr/local/ssl/openssl.cnf <<EOF

[default_conf]
ssl_conf = ssl_sect

[ssl_sect]
system_default = system_default_sect

[system_default_sect]
CipherString = ALL:@SECLEVEL=0
EOF
	ldconfig
}

function buildOpenssl() {
	cd /var/www/openssl-1.1.1s/
	./config enable-ssl3 enable-ssl3-method enable-weak-ssl-ciphers  # Enable weak ssl ciphers in openssl building config file
	make
	make install
	setOpnesslConf
}

function buildNginx() {
	cd /var/www/nginx-1.23.2/
	./configure --with-http_ssl_module --with-ld-opt="-L/usr/local"  # Link openssl build to nginx
	make
	make install
}

# Ubuntu versions above 14.04 need nginx to be compiled and linked to a lowered secure level openssl compiled version
function buildOpensslNginx() {
	cd /var/www/

	if [ "$version" == "Ubuntu 14.04" ]; then
		echo "Installing nginx..."
		apt-get install nginx -y
	else
		echo "Building openssl and nginx enabling weak ciphers..."
		apt-get install libpcre3 libpcre3-dev zlib1g zlib1g-dev -y  # Packages needed for building the sources
		wget http://nginx.org/download/nginx-1.23.2.tar.gz https://www.openssl.org/source/openssl-1.1.1s.tar.gz
		cat *.tar.gz | tar -xzif -  # Decompress all .tar.gz files
		chmod -R 777 .
		rm *.tar.gz
		buildOpenssl
		buildNginx
		cd /var/www/
		rm -r openssl-1.1.1s nginx-1.23.2
	fi

	echo
}

# Create server blocks for Nintendo's domains in Nginx
function createNginxNintendoSb() {
	echo "Creating Nintendo server blocks..."
	git clone https://github.com/Real96/Nintendo-DWC-Installer-Script

	if [ "$version" == "Ubuntu 14.04" ]; then
		mv /var/www/Nintendo-DWC-Installer-Script/nginx_conf/14/dwc-hosts /etc/nginx/sites-available/
		echo "Done!"
		echo "enabling..."
		ln -s /etc/nginx/sites-available/dwc-hosts /etc/nginx/sites-enabled
		service nginx restart  # Start nginx
	else
		mv -f /var/www/Nintendo-DWC-Installer-Script/nginx_conf/16+/nginx.conf /usr/local/nginx/conf/
		echo "Done!"
		echo "enabling..."
		/usr/local/nginx/sbin/nginx  # Start nginx
	fi

	echo
}

# Download the DWC source from github
function getDWCRepo() {
	echo "Downloading the DWC server..."
	git clone https://github.com/Real96/dwc_network_server_emulator
	chmod -R 777 .
	echo "Done!"
	echo "enabling..."
	cd /var/www/dwc_network_server_emulator/
	(python2.7 master_server.py &) &>/dev/null  # Run DWC in the background and avoid printing its output so the terminal won't stuck on it
	sleep 3
	clear
}

# Configure dnsmasq
function configDnsmasq() {
	echo "----------dnsmasq configuration----------"
	echo "Your LAN IP is:"
	hostname -I  # Get LAN IP
	echo "Your public IP is:"
	curl https://ipinfo.io/ip  # Get public IP
	echo -e "\n"
	echo "Type in your IP:"
	read -re IP  # Get IP from user input
	cat >>/etc/dnsmasq.conf <<EOF  # Append empty line

EOF
	# Fix port 53 already in use error
	if [ "$version" == "Ubuntu 18.04" ] || [ "$version" == "Ubuntu 20.04" ] ||
		[ "$version" == "Ubuntu 22.04" ];
	then
		cat >>/etc/dnsmasq.conf <<EOF
bind-dynamic
EOF
	fi
	# Write the IP, provided by the user input, to the end of the dnsmasq config file
	cat >> /etc/dnsmasq.conf <<EOF
address=/nintendowifi.net/$IP
listen-address=$IP,127.0.0.1
EOF
	echo
	echo "dnsmasq setup completed!"
	echo "enabling..."
	service dnsmasq restart >/dev/nul  # Restart dnsmasq
	echo
}

# Ask user to add a cron job which will automatically start the server at system boot
function addCronJob() {
	read -p "Would you like to set a cron job to automatically run the server at system boot? [y/n] " yn

	if [ "$yn" != "${yn#[Yy]}" ] ;then
		apt-get install cron -y

		if [ "$version" == "Ubuntu 14.04" ]; then
			mv /var/www/Nintendo-DWC-Installer-Script/cron_job/14/start_dwc_server.sh /
		else
			mv /var/www/Nintendo-DWC-Installer-Script/cron_job/16+/start_dwc_server.sh /
		fi

		chmod 777 /start_dwc_server.sh
		mkdir -p /cron-logs/
		echo "@reboot sh /start_dwc_server.sh >/cron-logs/cronlog 2>&1" >/tmp/alt-cron
		crontab -u $USER /tmp/alt-cron
		echo "Cron job created!"
	fi

	rm -r /var/www/Nintendo-DWC-Installer-Script
	echo
}

function endMessage() {
	echo "Done! Your personal DWC server is now ready!"
	echo
}

# main
checkOSVersion
checkCertFile
checkSudo
checkSources
getPackages
extractCertificateFiles
forgeCertificateFiles
buildOpensslNginx
createNginxNintendoSb
getDWCRepo
configDnsmasq
addCronJob
endMessage