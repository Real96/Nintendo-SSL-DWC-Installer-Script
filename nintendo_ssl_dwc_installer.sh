#!/bin/bash

# Fix rm error
shopt -s extglob

# Set Linux version variable
. /etc/os-release
version="$NAME $VERSION_ID"

function checkOSVersion() {
    if [[ "$NAME" == "Ubuntu" && $VERSION_ID -lt 14 ]] || [[ "$NAME" == "Debian GNU/Linux" && $VERSION_ID -lt 9 ]] ||
        [[ "$NAME" != "Ubuntu" && "$NAME" != "Debian GNU/Linux" ]];
    then
        echo -e "This Linux distro is not currently supported!\nSupported distro: Ubuntu 14+ or Debian 9+"

        exit 1
    fi
}

# Check if "00000011.app" file exists
function checkCertFile() {
    if [ ! -f "00000011.app" ]; then
        echo -e "Unable to find \"00000011.app\" NAND file!\nBe sure to put it in the same path of the script\n"

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
        echo -e "All needed sources are reachable!\n"
    else
        echo -e "Unable to reach all the needed sources!\n"

        exit 1
    fi
}

# Add Ubuntu 22.04 repository for Python2.7 source file
function addUbuntuRepo() {
    cat >>/etc/apt/sources.list.d/ubuntu.sources <<EOF

Types: deb
URIs: http://it.archive.ubuntu.com/ubuntu/
Suites: jammy jammy-updates
Components: universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
}

# Add Debian 11 repository for Python2.7 source file
function addDebianRepo() {
    cat >>/etc/apt/sources.list <<EOF

deb http://deb.debian.org/debian bullseye main contrib non-free
EOF
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

    if [ "$version" == "Ubuntu 24.04" ]; then
        addUbuntuRepo
    elif [ "$version" == "Debian GNU/Linux 12" ]; then
        addDebianRepo
    fi

    apt-get update
    apt-get install make gcc python2.7 dnsmasq git net-tools wget -y

    if [ "$version" == "Ubuntu 20.04" ] || [ "$version" == "Ubuntu 22.04" ] ||
        [ "$version" == "Ubuntu 24.04" ] || [ "$version" == "Debian GNU/Linux 11" ] ||
        [ "$version" == "Debian GNU/Linux 12" ];
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
    openssl x509 -req -in server.csr -CA NWC.crt -CAkey NWC.key -CAcreateserial -out server.crt -days 7305 -sha1
    cat server.crt NWC.crt > server-chain.crt
    rm !("server.key"|"server-chain.crt")
    echo
}

function buildOpenssl() {
    cd /var/www/openssl-1.1.1w/
    ./config no-shared
}

function buildNginx() {
    cd /var/www/nginx-1.26.3/
    apt-get install libpcre3-dev zlib1g-dev -y  # Packages needed for building nginx source
    ./configure \
    --with-http_ssl_module \
    --with-openssl=/var/www/openssl-1.1.1w \
    --with-openssl-opt="enable-ssl3 enable-ssl3-method enable-weak-ssl-ciphers"  # Configure openssl for nginx static compilation
    make
    make install
}

# Ubuntu versions above 14.04 need nginx to be compiled with a lowered secure level openssl
function buildOpensslNginx() {
    cd /var/www/

    if [ "$version" == "Ubuntu 14.04" ]; then
        echo "Installing nginx..."
        apt-get install nginx -y
    else
        echo "Building openssl and nginx enabling weak ciphers..."
        wget http://nginx.org/download/nginx-1.26.3.tar.gz https://www.openssl.org/source/openssl-1.1.1w.tar.gz
        cat *.tar.gz | tar -xzif -  # Decompress all .tar.gz files
        rm *.tar.gz
        chmod -R 777 .
        buildOpenssl
        buildNginx
        cd /var/www/
        rm -r openssl-1.1.1w nginx-1.26.3
    fi

    echo
}

# Create server blocks for Nintendo's domains in Nginx
function createNginxNintendoSb() {
    echo "Creating Nintendo server blocks..."
    git clone https://github.com/Real96/Nintendo-DWC-Installer-Script

    if [ "$version" == "Ubuntu 14.04" ]; then
        mv /var/www/Nintendo-DWC-Installer-Script/nginx_conf/14/dwc-hosts /etc/nginx/sites-available/
        echo -e "Done!\nenabling...\n"
        ln -s /etc/nginx/sites-available/dwc-hosts /etc/nginx/sites-enabled
        service nginx restart  # Start nginx
    else
        mv -f /var/www/Nintendo-DWC-Installer-Script/nginx_conf/16+/nginx.conf /usr/local/nginx/conf/
        echo -e "Done!\nenabling...\n"
        /usr/local/nginx/sbin/nginx  # Start nginx
    fi
}

# Download the DWC source from github
function getDWCRepo() {
    echo "Downloading the DWC server..."
    git clone https://github.com/Real96/dwc_network_server_emulator
    chmod -R 777 .
    echo -e "Done!\nenabling..."
    cd /var/www/dwc_network_server_emulator/
    (python2.7 master_server.py &) &>/dev/null  # Run DWC in the background and avoid printing its output so the terminal won't stuck on it
    sleep 3
    clear
}

# Configure dnsmasq
function configDnsmasq() {
    echo -e "----------dnsmasq configuration----------\n\nYour LAN IP is:"
    hostname -I  # Get LAN IP
    echo -e "\nYour public IP is:"
    wget -q -O - ipinfo.io/ip  # Get public IP
    echo -e "\n\nType in your IP:"
    read -re IP  # Get IP from user input
    cat >>/etc/dnsmasq.conf <<EOF  # Append empty line

EOF
    # Fix port 53 already in use error
    if [ "$version" == "Ubuntu 18.04" ] || [ "$version" == "Ubuntu 20.04" ] ||
        [ "$version" == "Ubuntu 22.04" ] || [ "$version" == "Ubuntu 24.04" ];
    then
        cat >>/etc/dnsmasq.conf <<EOF
bind-dynamic
EOF
    fi
    # Write the IP, provided by the user input, to the end of the dnsmasq config file
    cat >> /etc/dnsmasq.conf <<EOF
address=/nintendowifi.net/$IP
listen-address=$IP,127.0.0.1
no-resolv
EOF
    echo -e "\ndnsmasq setup completed!\nenabling...\n"
    service dnsmasq restart >/dev/nul  # Restart dnsmasq
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
        echo "@reboot sh /start_dwc_server.sh" >/tmp/dwc-cron
        crontab -u $USER /tmp/dwc-cron
        echo -e "\nCron job created!\n"
    fi

    rm -r /var/www/Nintendo-DWC-Installer-Script
}

function endMessage() {
    echo -e "Done! Your personal DWC server is now ready!\n"
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