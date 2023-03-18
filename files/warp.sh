#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统, 请使用主流的操作系统" && exit 1

menu(){
    clear
    echo "#############################################################"
    echo -e "#                ${RED}CloudFlare WARP 一键管理脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misaka_noc                    #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misaka_noc_chat               #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 WARP-GO"
    echo -e " ${GREEN}4.${PLAIN} ${RED}卸载 WARP-GO${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}5.${PLAIN} 安装 WARP-Cli"
    echo -e " ${GREEN}6.${PLAIN} ${RED}卸载 WARP-Cli${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}7.${PLAIN} 安装 WireProxy-WARP"
    echo -e " ${GREEN}8.${PLAIN} ${RED}卸载 WireProxy-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}9.${PLAIN} 修改 WARP-Cli / WireProxy 端口"
    echo -e " ${GREEN}10.${PLAIN} 开启、关闭或重启 WARP"
    echo -e " ${GREEN}11.${PLAIN} 提取 WireGuard 配置文件"
    echo -e " ${GREEN}12.${PLAIN} WARP+ 账户刷流量"
    echo -e " ${GREEN}13.${PLAIN} 切换 WARP 账户类型"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    #ipinfo
    #echo ""
    read -rp "请输入选项 [0-13]: " menuInput
    case $menuInput in
        1 ) infowgcf ;;
        2 ) unstwgcf ;;
        3 ) infowpgo ;;
        4 ) unstwpgo ;;
        5 ) installcli ;;
        6 ) uninstallcli ;;
        7 ) installWireProxy ;;
        8 ) uninstallWireProxy ;;
        9 ) warpport ;;
        10 ) warpswitch ;;
        11 ) wgprofile ;;
        12 ) warptraffic ;;
        13 ) warpaccount ;;
        * ) exit 1 ;;
    esac
}

menu