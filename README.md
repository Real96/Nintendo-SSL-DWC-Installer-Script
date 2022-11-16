# Nintendo DWC Installer Script
Bash script which installs a Nintendo DWC server on your PC

## Requirements
- Linux Ubuntu 14 or upper or Linux Debian 9 or upper. Can be installed also in a virtual machine, with bridged network
- File `00000011.app`, which can be extracted from a Nintendo Wii NAND dump
- WiFi with WEP/no protection, wireless type 802.1.1b and frequency 2.4GHz

## Fix error "User is not in sudoers file" in Debian
- `su -`
- `apt-get install sudo`
- `usermod -aG sudo USER_NAME`
- `reboot`

## Usage
- Put the script and the file `00000011.app` in the same folder
- cd `/path/to/nintendo_dwc_installer.sh`
- `./nintendo_dwc_installer.sh`
