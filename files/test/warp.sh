#!/bin/bash

# 环境变量，用于在 Debian 或 Ubuntu 操作系统中设置非交互式（noninteractive）安装模式

export DEBIAN_FRONTEND=noninteractive

# 彩色文字
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 多方式判断操作系统，如非支持的操作系统，则退出脚本
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

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

# 检测并安装依赖
check_depend(){
    # 非 CentOS 系系统，执行软件包更新
    [[ ! $SYSTEM == "CentOS" ]] && ${PACKAGE_UPDATE[int]}

    # 安装相应依赖
    [[ -z $(type -P curl) ]] && ${PACKAGE_INSTALL[int]} curl
    [[ -z $(type -P wget) ]] && ${PACKAGE_INSTALL[int]} wget
    [[ -z $(type -P sudo) ]] && ${PACKAGE_INSTALL[int]} sudo
    [[ -z $(type -P python3) ]] && ${PACKAGE_INSTALL[int]} python3
    [[ -z $(type -P qrencode) ]] && ${PACKAGE_INSTALL[int]} qrencode
}

# IPv4 出站状态检测
ipv4_out_check(){
    ipv4_out_ip=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep ip | cut -d= -f2)
    ipv4_ip_country=$(curl -s4m8 ipget.net/country?ip="$ipv4_out_ip")
    ipv4_warp_stat=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

# IPv6 出站状态检测
ipv6_out_check(){
    ipv6_out_ip=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep ip | cut -d= -f2)
    ipv6_ip_country=$(curl -s6m8 ipget.net/country?ip="$ipv6_out_ip")
    ipv6_warp_stat=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

