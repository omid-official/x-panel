#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} You must use the root user to run this script!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
     release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
     release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
     release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
     release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
     release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
     release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
     release="centos"
else
     echo -e "${red}The system version is not detected, please contact the script author! ${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
   arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
   arch="arm64"
else
   arch="amd64"
   echo -e "${red} failed to detect architecture, use default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
     echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64). If the detection is incorrect, please contact the author"
     exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
     os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
     os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
     if [[ ${os_version} -le 6 ]]; then
         echo -e "${red}Please use CentOS 7 or higher! ${plain}\n" && exit 1
     fi
elif [[ x"${release}" == x"ubuntu" ]]; then
     if [[ ${os_version} -lt 16 ]]; then
         echo -e "${red}Please use Ubuntu 16 or higher! ${plain}\n" && exit 1
     fi
elif [[ x"${release}" == x"debian" ]]; then
     if [[ ${os_version} -lt 8 ]]; then
         echo -e "${red}Please use Debian 8 or higher version system! ${plain}\n" && exit 1
     fi
fi

install_base() {
     if [[ x"${release}" == x"centos" ]]; then
         yum install wget curl tar -y
     else
         apt install wget curl tar -y
     fi
}

install_x-panel() {
     systemctl stop x-panel
     cd /usr/local/

     if [ $# == 0 ] ;then
         last_version=$(curl -Ls "https://api.github.com/repos/omid-the-great/x-panel/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'))
         if [[ ! -n "$last_version" ]]; then
             echo -e "${red} failed to detect the x-panel version. It may have exceeded the Github API limit. Please try again later, or manually specify the x-panel version to install ${plain}"
             exit 1
         fi
         echo -e "Detected the latest version of x-panel: ${last_version}, start installation"
         wget -N --no-check-certificate -O /usr/local/x-panel-linux-${arch}.tar.gz https://github.com/omid-the-great/x-panel/releases /download/${last_version}/x-panel-linux-${arch}.tar.gz
         if [[ $? -ne 0 ]]; then
             echo -e "${red} failed to download x-panel, please make sure your server can download Github files ${plain}"
             exit 1
         fi
     else
         last_version=$1
         url="https://github.com/omid-the-great/x-panel/releases/download/${last_version}/x-panel-linux-${arch}.tar.gz"
         echo -e "Start installing x-panel v$1"
         wget -N --no-check-certificate -O /usr/local/x-panel-linux-${arch}.tar.gz ${url}
         if [[ $? -ne 0 ]]; then
             echo -e "${red} failed to download x-panel v$1, please make sure this version exists ${plain}"
             exit 1
         fi
     fi

     if [[ -e /usr/local/x-panel/ ]]; then
         rm /usr/local/x-panel/ -rf
     fi

     tar zxvf x-panel-linux-${arch}.tar.gz
     rm x-panel-linux-${arch}.tar.gz -f
     cd x-panel
     chmod +x x-panel bin/xray-linux-${arch} x-panel.sh
     cp -f x-panel.service /etc/systemd/system/
     cp -f x-panel.sh /usr/bin/x-panel
     systemctl daemon-reload
     systemctl enable x-panel
     systemctl start x-panel
     echo -e "${green}x-panel v${last_version}${plain} installation is complete and the panel has been started,"
     echo -e ""
     echo -e "If it is a new installation, the default web port is ${green}54321${plain}, and the default username and password are ${green}admin${plain}"
     echo -e "Please ensure that this port is not occupied by other programs, ${yellow} and ensure that port 54321 has been released ${plain}"
# echo -e "If you want to change 54321 to another port, enter the x-panel command to modify it. Also make sure that the port you modify is also allowed."
     echo -e ""
     echo -e "If you are updating the panel, access the panel as you did before"
     echo -e ""
     echo -e "How to use x-panel management script: "
     echo -e "------------------------------------------------- "
     echo -e "x-panel - show management menu (more functions)"
     echo -e "x-panel start - Start x-panel panel"
     echo -e "x-panel stop - Stop x-panel panel"
     echo -e "x-panel restart - Restart the x-panel panel"
     echo -e "x-panel status - View x-panel status"
     echo -e "x-panel enable - Set x-panel to start automatically at boot"
     echo -e "x-panel disable - Cancel x-panel startup at boot"
     echo -e "x-panel log - View x-panel log"
#     echo -e "x-panel v2-ui - migrate the v2-ui account data of this machine to x-panel"
     echo -e "x-panel update - Update x-panel panel"
     echo -e "x-panel install - install x-panel panel"
     echo -e "x-panel uninstall - Uninstall x-panel panel"
     echo -e "------------------------------------------------- "
}

echo -e "${green} starts installing ${plain}"
install_base
install_x-panel $1