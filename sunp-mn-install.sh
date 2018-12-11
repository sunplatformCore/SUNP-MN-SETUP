#!/bin/bash

# Variables
RED_TEXT=`tput setaf 1`
GREEN_TEXT=`tput setaf 2`
RESET_TEXT=`tput sgr0`
REQUIRED_UBUNTU_VERSION="16.04"

# clear screen
clear

# Required Ubuntu Version check
echo -n 'Checking Ubuntu Linux Version...'
if [[ `lsb_release -rs` == $REQUIRED_UBUNTU_VERSION ]]
then
	echo "${GREEN_TEXT} 16.04 OK ${RESET_TEXT}"; echo ""
else
	echo "${RED_TEXT} Your Server is not running Ubuntu $REQUIRED_UBUNTU_VERSION, please upgrade to Ubuntu $REQUIRED_UBUNTU_VERSION ! The script will be terminated... ${RESET_TEXT}"; echo ""
	exit
fi

read -e -p "Is your VPS Provider allowing to create SWAP file? If not sure hit enter! [Y/n] : " swapallowed
if [[ ("$swapallowed" == "y" || "$swapallowed" == "Y") ]]; then
  echo "Creating 2GB SWAP file..."
  sudo touch /mnt/swap.img
  sudo chmod 0600 /mnt/swap.img
  dd if=/dev/zero of=/mnt/swap.img bs=1024k count=2000
  sudo mkswap /mnt/swap.img
  sudo swapon /mnt/swap.img
  sudo echo "/mnt/swap.img none swap sw 0 0" >> /etc/fstab
  echo ""
fi

echo "Make sure you double check before pressing enter! One chance at this only!"; echo ""

# Ask for important Data for configuring Masternode
read -e -p "Server IP Address : " ip
read -e -p "Masternode Private Key (Generate via local Wallet Debug Console -> masternode genkey) : " key
read -e -p "Install Fail2ban? [Y/n] : " install_fail2ban
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

# Update, upgrade Ubuntu and install required packages
clear
cd ~
echo "Updating system and installing required packages..."
sudo apt-get -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo apt-get -y autoremove
sudo apt-get install curl wget nano htop -y
sudo apt-get install automake build-essential libtool autotools-dev autoconf pkg-config libssl-dev -y
sudo apt-get install libboost-all-dev git npm nodejs nodejs-legacy libminiupnpc-dev redis-server -y
sudo apt-get install software-properties-common -y
sudo apt-get install libevent-dev -y
add-apt-repository ppa:bitcoin/bitcoin -y
apt-get update -y
apt-get install libdb4.8-dev libdb4.8++-dev -y
source ~/.profile
apt-get -y install aptitude
echo ""

# Download Wallet files and copying to /usr/local/bin
echo "Downloading Wallet files and extracting..."
mkdir ~/sunplatform/
wget https://github.com/sunplatformCore/sunplatform/releases/download/v1.0.0/sunplatformd
wget https://github.com/sunplatformCore/sunplatform/releases/download/v1.0.0/sunplatform-cli
wget https://github.com/sunplatformCore/sunplatform/releases/download/v1.0.0/sunplatform-tx


cd ~/sunplatform
cp -f sunplatformd /usr/local/bin
cp -f sunplatform-cli /usr/local/bin
cp -f sunplatform-tx /usr/local/bin
echo ""

# Delete Files
echo "Deleting unnecessary files..."
rm -rf ~/sunplatform/
echo ""

# Crontab entry to start sunplatform after server reboot
echo "Creating crontab entry..."
(crontab -l ; echo "@reboot sleep 15 && /usr/local/bin/sunplatformd -daemon -shrinkdebugfile")| crontab -
echo ""

# Installing, configuring Firewall and Fail2Ban
if [[ ("$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "") ]]; then
  echo "Installing and starting Fail2Ban..."
  cd ~
  sudo aptitude -y install fail2ban
  sudo service fail2ban restart
  echo ""
fi
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  echo "Installing and starting Firewall..."
  sudo apt-get install ufw
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw logging on
  sudo ufw allow ssh/tcp
  sudo ufw limit ssh/tcp
  sudo ufw allow 8329/tcp
  sudo ufw allow 8330/tcp
  sudo echo "y" | sudo ufw enable
  echo ""
fi

# Generating Random Passwords, creating sunplatform.conf file
echo "Creating sunplatform.conf file..."
password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
password2=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`

sudo mkdir ~/.sunplatform
sudo touch ~/.sunplatform/sunplatform.conf
echo 'rpcuser='$password'
rpcpassword='$password2'
rpcallowip=127.0.0.1
rpcport=62891
masternodeaddr=127.0.0.1:62890
externalip='$ip'
listen=1
server=1
daemon=1
maxconnections=128
masternode=1
masternodeprivkey='$key'
addnode=202.182.109.148
' | sudo -E tee ~/.sunplatform/sunplatform.conf >/dev/null 2>&1
    sudo chmod 0600 ~/.sunplatform/sunplatform.conf
echo ""

# Starting sunplatform daemon
echo "Starting Masternode..."
sunplatformd -daemon
echo ""
echo "${RED_TEXT}Please start you masternode via local desktop wallet debug console -> masternode start-alias YOURMASTERNODEALIAS !${RESET_TEXT}"; echo ""
read -p "After starting your Masternode, press any key to continue... " -n1 -s
echo ""

# Show Version and Masternde Info
echo "Getting Masternode Output (60 sec waiting time...)"
sleep 60
sunplatform-cli getinfo
rm -f ~/sunp-mn-install.sh