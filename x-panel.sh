#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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

confirm() {
     if [[ $# > 1 ]]; then
         echo && read -p "$1 [default $2]: " temp
         if [[ x"${temp}" == x"" ]]; then
             temp=$2
         fi
     else
         read -p "$1 [y/n]: " temp
     fi
     if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
         return 0
     else
         return 1
     fi
}

confirm_restart() {
     confirm "Whether to restart the panel, restarting the panel will also restart xray" "y"
     if [[ $? == 0 ]]; then
         restart
     else
         show_menu
     fi
}

before_show_menu() {
     echo && echo -n -e "${yellow} Press Enter to return to the main menu: ${plain}" && read temp
     show_menu
}

install() {
     bash <(curl -Ls https://raw.githubusercontent.com/omid-the-great/x-panel/master/install.sh)
     if [[ $? == 0 ]]; then
         if [[ $# == 0 ]]; then
             start
         else
             start 0
         fi
     fi
}

update() {
     confirm "This function will force reinstall the latest version without losing data. Do you want to continue?" "n"
     if [[ $? != 0 ]]; then
         echo -e "${red} canceled ${plain}"
         if [[ $# == 0 ]]; then
             before_show_menu
         fi
         return 0
     fi
     bash <(curl -Ls https://raw.githubusercontent.com/omid-the-great/x-panel/master/install.sh)
     if [[ $? == 0 ]]; then
         echo -e "${green} update completed, panel has been automatically restarted ${plain}"
         exit 0
     fi
}

uninstall() {
     confirm "Are you sure you want to uninstall the panel? Xray will also be uninstalled?" "n"
     if [[ $? != 0 ]]; then
         if [[ $# == 0 ]]; then
             show_menu
         fi
         return 0
     fi
     systemctl stop x-panel
     systemctl disable x-panel
     rm /etc/systemd/system/x-panel.service -f
     systemctl daemon-reload
     systemctl reset-failed
     rm /etc/x-panel/ -rf
     rm /usr/local/x-panel/ -rf

     echo ""
     echo -e "Uninstallation successful. If you want to delete this script, exit the script and run ${green}rm /usr/bin/x-panel -f${plain} to delete it"
     echo ""

     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

reset_user() {
     confirm "Are you sure you want to reset your username and password to admin" "n"
     if [[ $? != 0 ]]; then
         if [[ $# == 0 ]]; then
             show_menu
         fi
         return 0
     fi
     /usr/local/x-panel/x-panel setting -username admin -password admin
     echo -e "The username and password have been reset to ${green}admin${plain}, please restart the panel now"
     confirm_restart
}

reset_config() {
     confirm "Are you sure you want to reset all panel settings? Account data will not be lost, username and password will not be changed" "n"
     if [[ $? != 0 ]]; then
         if [[ $# == 0 ]]; then
             show_menu
         fi
         return 0
     fi
     /usr/local/x-panel/x-panel setting -reset
     echo -e "All panel settings have been reset to default values. Now please restart the panel and use the default ${green}54321${plain} port to access the panel"
     confirm_restart
}

set_port() {
     echo && echo -n -e "Enter port number [1-65535]: " && read port
     if [[ -z "${port}" ]]; then
         echo -e "${yellow} canceled ${plain}"
         before_show_menu
     else
         /usr/local/x-panel/x-panel setting -port ${port}
         echo -e "The port setting is completed, please restart the panel now and use the newly set port ${green}${port}${plain} to access the panel"
         confirm_restart
     fi
}

start() {
     check_status
     if [[ $? == 0 ]]; then
         echo ""
         echo -e "The ${green} panel is already running and does not need to be started again. If you need to restart, please choose restart ${plain}"
     else
         systemctl start x-panel
         sleep 2
         check_status
         if [[ $? == 0 ]]; then
             echo -e "${green}x-panel started successfully ${plain}"
         else
             echo -e "The ${red} panel failed to start. It may be because the startup time exceeded two seconds. Please check the log information later ${plain}"
         fi
     fi

     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

stop() {
     check_status
     if [[ $? == 1 ]]; then
         echo ""
         echo -e "${green} panel has been stopped, no need to stop again ${plain}"
     else
         systemctl stop x-panel
         sleep 2
         check_status
         if [[ $? == 1 ]]; then
             echo -e "${green}x-panel and xray stopped successfully ${plain}"
         else
             elseecho -e "The ${red} panel failed to stop, possibly because the stop time exceeded two seconds. Please check the log information later ${plain}"
         fi
     fi

     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

restart() {
     systemctl restart x-panel
     sleep 2
     check_status
     if [[ $? == 0 ]]; then
         echo -e "${green}x-panel and xray restarted successfully ${plain}"
     else
         echo -e "${red} panel failed to restart, possibly because the startup time exceeded two seconds. Please check the log information later ${plain}"
     fi
     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

status() {
     systemctl status x-panel -l
     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

enable() {
     systemctl enable x-panel
     if [[ $? == 0 ]]; then
         echo -e "${green}x-panel set up auto-start successfully ${plain}"
     else
         echo -e "${red}x-panel failed to set up auto-start at boot ${plain}"
     fi

     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

disable() {
     systemctl disable x-panel
     if [[ $? == 0 ]]; then
         echo -e "${green}x-panel Cancel boot and start successfully ${plain}"
     else
         echo -e "${red}x-panel failed to cancel boot auto-start ${plain}"
     fi

     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

show_log() {
     journalctl -u x-panel.service -e --no-pager -f
     if [[ $# == 0 ]]; then
         before_show_menu
     fi
}

#migrate_v2_ui() {
#     /usr/local/x-panel/x-panel v2-ui
#
#     before_show_menu
#}

install_bbr() {
     # temporary workaround for installing bbr
     bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
     echo ""
     before_show_menu
}

update_shell() {
     wget -O /usr/bin/x-panel -N --no-check-certificate https://github.com/omid-the-great/x-panel/raw/master/x-panel.sh
     if [[ $? != 0 ]]; then
         echo ""
         echo -e "${red} failed to download the script, please check whether the machine can connect to Github${plain}"
         before_show_menu
     else
         chmod +x /usr/bin/x-panel
         echo -e "${green} upgrade script successful, please re-run script ${plain}" && exit 0
     fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
     if [[ ! -f /etc/systemd/system/x-panel.service ]]; then
         return 2
     fi
     temp=$(systemctl status x-panel | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
     if [[ x"${temp}" == x"running" ]]; then
         return 0
     else
         return 1
     fi
}

check_enabled() {
     temp=$(systemctl is-enabled x-panel)
     if [[ x"${temp}" == x"enabled" ]]; then
         return 0
     else
         return 1;
     fi
}

check_uninstall() {
     check_status
     if [[ $? != 2 ]]; then
         echo ""
         echo -e "${red} panel has been installed, please do not re-install ${plain}"
         if [[ $# == 0 ]]; then
             before_show_menu
         fi
         return 1
     else
         return 0
     fi
}

check_install() {
     check_status
     if [[ $? == 2 ]]; then
         echo ""
         echo -e "${red}Please install the panel first${plain}"
         if [[ $# == 0 ]]; then
             before_show_menu
         fi
         return 1
     else
         return 0
     fi
}

show_status() {
     check_status
     case $? in
         0)
             echo -e "Panel status: ${green} is running ${plain}"
             show_enable_status
             ;;
         1)
             echo -e "Panel status: ${yellow} is not running ${plain}"
             show_enable_status
             ;;
         2)
             echo -e "Panel status: ${red} is not installed ${plain}"
     esac
     show_xray_status
}

show_enable_status() {
     check_enabled
     if [[ $? == 0 ]]; then
         echo -e "Whether it starts automatically at boot: ${green} is ${plain}"
     else
         echo -e "Whether to start automatically at boot: ${red}No${plain}"
     fi
}

check_xray_status() {
     count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
     if [[ count -ne 0 ]]; then
         return 0
     else
         return 1
     fi
}

show_xray_status() {
     check_xray_status
     if [[ $? == 0 ]]; then
         echo -e "xray status: ${green} running ${plain}"
     else
         echo -e "xray status: ${red} is not running ${plain}"
     fi
}

show_usage() {
     echo "How to use x-panel management script: "
     echo "---------------------------------------------"
     echo "x-panel - Show management menu (more functions)"
     echo "x-panel start - Start x-panel panel"
     echo "x-panel stop - Stop x-panel panel"
     echo "x-panel restart - Restart the x-panel panel"
     echo "x-panel status - View x-panel status"
     echo "x-panel enable - Set x-panel to start automatically at boot"
     echo "x-panel disable - cancel x-panel startup"
     echo "x-panel log - View x-panel log"
#     echo "x-panel v2-ui - migrate the v2-ui account data of this machine to x-panel"
     echo "x-panel update - Update x-panel panel"
     echo "x-panel install - install x-panel panel"
     echo "x-panel uninstall - Uninstall x-panel panel"
     echo "---------------------------------------------"
}

show_menu() {
     echo -e "
   ${green}x-panel panel management script${plain}
   ${green}0.${plain} exit script
————————————————
   ${green}1.${plain} Install x-panel
   ${green}2.${plain} Update x-panel
   ${green}3.${plain} Uninstall x-panel
————————————————
   ${green}4.${plain} Reset username and password
   ${green}5.${plain} Reset panel settings
   ${green}6.${plain} Set panel port
————————————————
   ${green}7.${plain} Start x-panel
   ${green}8.${plain} Stop x-panel
   ${green}9.${plain} Restart x-panel
  ${green}10.${plain} View x-panel status
  ${green}11.${plain} View x-panel log
————————————————
  ${green}12.${plain} Set x-panel to start automatically at boot
  ${green}13.${plain} Cancel x-panel to start automatically at boot
————————————————
  ${green}14.${plain} One-click installation of bbr (latest kernel)
  "
     show_status
     echo && read -p "Please enter selection [0-14]: " num

     case "${num}" in
         0) exit 0
         ;;
         1) check_uninstall && install
         ;;
         2) check_install && update
         ;;
         3) check_install && uninstall
         ;;
         4) check_install && reset_user
         ;;
         5) check_install && reset_config
         ;;
         6) check_install && set_port
         ;;
         7) check_install && start
         ;;
         8) check_install && stop
         ;;
         9) check_install && restart
         ;;
         10) check_install && status
         ;;
         11) check_install && show_log
         ;;
         12) check_install && enable
         ;;
         13) check_install && disable
         ;;
         14) install_bbr
         ;;
         *) echo -e "${red}Please enter the correct number [0-14]${plain}"
         ;;
     esac
}


if [[ $# > 0 ]]; then
     case $1 in
         "start") check_install 0 && start 0
         ;;
         "stop") check_install 0 && stop 0
         ;;
         "restart") check_install 0 && restart 0
         ;;
         "status") check_install 0 && status 0
         ;;
         "enable") check_install 0 && enable 0
         ;;
         "disable") check_install 0 && disable 0
         ;;
         "log") check_install 0 && show_log 0
         ;;
#         "v2-ui") check_install 0 && migrate_v2_ui 0
#         ;;
         "update") check_install 0 && update 0
         ;;
         "install") check_uninstall 0 && install 0
         ;;
         "uninstall") check_install 0 && uninstall 0
         ;;
         *) show_usage
     esac
else
     show_menu
fi