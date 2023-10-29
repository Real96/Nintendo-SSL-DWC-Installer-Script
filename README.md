# Nintendo SSL DWC Installer Script
Bash script which installs [this](https://github.com/Real96/dwc_network_server_emulator) Nintendo DWC server emulator with SSL support on your PC.

## Requirements
- VPS or virtual machine with bridged network
- Linux Ubuntu 14 or upper or Linux Debian 9 or upper
- File `00000011.app`, which can be extracted from a Nintendo Wii NAND dump
- WiFi with WEP/no protection, wireless type 802.11b and frequency 2.4GHz

## Fix error "User is not in sudoers file" in Debian
- `su -`
- `apt-get install sudo`
- `usermod -aG sudo USER_NAME`
- `reboot`

## Usage
- `sudo apt-get update && sudo apt-get upgrade && sudo apt-get dist-upgrade && sudo apt-get autoremove && sudo apt-get autoclean`
- Put the script and the file `00000011.app` in the same folder
- Open ports `53`, `80` and `443` if you use a VPS or your public IP
- `cd /path/to/nintendo_ssl_dwc_installer.sh`
- `chmod 777 nintendo_ssl_dwc_installer.sh`
- `./nintendo_ssl_dwc_installer.sh`

## Fix dnsmasq not handling DNS requests in Azure VPS
In Azure VPS (and probably in some others) you have to use the local IP instead of the public one.

## Credits
- [shutterbug2000](https://github.com/shutterbug2000) who discovered the [flaw](https://github.com/KaeruTeam/nds-constraint)
- [Vega](https://mariokartwii.com/member.php?action=profile&uid=1) for his DWC emulator setup [guide](https://mariokartwii.com/showthread.php?tid=885)
- [flewkey](https://flewkey.com/about.html) for his [guide](https://flewkey.com/blog/2020-07-12-nds-constraint.html) about the SSL setup and for his help
