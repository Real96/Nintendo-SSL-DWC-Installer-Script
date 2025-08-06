# Nintendo SSL DWC Installer Script
Bash script which installs [this](https://github.com/Real96/dwc_network_server_emulator) Nintendo DWC server emulator with SSL support on your PC.

## Requirements
- VPS or virtual machine with bridged network
- Linux Ubuntu 14.04 or upper (16.04, 18.04, 20.04, 22.04, 24.04) or Linux Debian 9 or upper (10, 11, 12)
- File `00000011.app`, which can be easily extracted from a Nintendo Wii NAND dump or downloaded following [this](https://it.dolphin-emu.org/docs/guides/wii-network-guide) guide (section `Other versions of Dolphin`)
- WiFi with WEP/no protection, wireless type 802.11b and frequency 2.4GHz

## Fix error "User is not in sudoers file" in Debian
- `su -`
- `apt-get install sudo`
- `usermod -aG sudo USER_NAME`
- `reboot`

## Usage
- `sudo apt-get update && sudo apt-get upgrade && sudo apt-get dist-upgrade && sudo apt-get autoremove && sudo apt-get autoclean`
- Put the script and the file `00000011.app` in the same folder
- If you use a VPS or your public IP, open the following ports:
  - `53` (TCP/UDP)
  - `80` (TCP)
  - `443` (TCP) 
  - `8000` (TCP)
  - `9000` (TCP) 
  - `9001` (TCP)
  - `9002` (TCP) 
  - `9003` (TCP)
  - `9009` (TCP) 
  - `9998` (TCP)
  - `27500` (TCP)
  - `27900` (TCP) 
  - `27901` (TCP)
  - `28910` (TCP) 
  - `29900` (TCP)
  - `29901` (TCP)
  - `29920` (TCP) 
- `cd /path/to/nintendo_ssl_dwc_installer.sh`
- `chmod 777 nintendo_ssl_dwc_installer.sh`
- `./nintendo_ssl_dwc_installer.sh`

## Fix dnsmasq not handling DNS requests in Azure VPS
In Azure VPS (and probably in some others) you have to use the local IP instead of the public one.

## Credits
- [shutterbug2000](https://github.com/shutterbug2000) who discovered the [flaw](https://github.com/KaeruTeam/nds-constraint)
- [Vega](https://mariokartwii.com/member.php?action=profile&uid=1) for his DWC emulator setup [guide](https://mariokartwii.com/showthread.php?tid=885)
- [flewkey](https://flewkey.com/about.html) for his [guide](https://flewkey.com/blog/2020-07-12-nds-constraint.html) about the SSL setup and for his help
