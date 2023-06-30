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

[[ -z $SYSTEM ]] && red "不支持当前 VPS 的操作系统, 请使用主流的操作系统" && exit 1

# 注册 WARP 账户
warp_acc_register(){
    if [[ $(type -P wg) ]]; then
        private_key=$(wg genkey)
        public_key=$(wg pubkey <<< "$private_key")
    else
        wg_api=$(curl -sSL https://wg.cloudflare.now.cc)
        private_key=$(echo "$wg_api" | awk 'NR==2 {print $2}')
        public_key=$(echo "$wg_api" | awk 'NR==1 {print $2}')
    fi

    install_id=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)
    fcm_token="${install_id}:APA91b$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)"

    curl --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
        --silent \
        --location \
        --tlsv1.3 \
        --header 'User-Agent: okhttp/3.12.1' \
        --header 'CF-Client-Version: a-6.10-2158' \
        --header 'Content-Type: application/json' \
        --header "Cf-Access-Jwt-Assertion: ${team_token}" \
        --data '{"key":"'${public_key}'","install_id":"'${install_id}'","fcm_token":"'${fcm_token}'","tos":"'$(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"PC","serial_number":"'${install_id}'","locale":"zh_CN"}' \
    | python3 -m json.tool | sed "/\"account_type\"/i\        \"private_key\": \"$private_key\"" > warp-account.conf
}

# 安装 WireGuard WARP
select_wgwarp(){
    yellow "请选择 WireGuard 安装 / 切换的模式"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WireGuard-WARP 单栈模式 ${YELLOW}(IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 / 切换 WireGuard-WARP 单栈模式 ${YELLOW}(IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 WireGuard-WARP 双栈模式"
    echo ""
    read -p "请输入选项 [1-3]: " wgwarp_mode
    if [ $wgwarp_mode = 1 ]; then
        install_wgwarp_ipv4
    elif [ $wgwarp_mode = 2 ]; then
        install_wgwarp_ipv6
    elif [ $wgwarp_mode = 3 ]; then
        install_wgwarp_dual
    else
        red "输入错误，请重新输入"
        select_wgwarp
    fi
}

install_wgwarp(){
    # 安装必需依赖
    if [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep net-tools iproute2 openresolv openrc iptables ip6tables wireguard-tools
    fi
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl unzip lsb-release bc htop screen python3 inetutils-ping qrencode
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip lsb-release bc htop screen python3 inetutils-ping qrencode
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi

    # IPv4 only VPS 开启 IPv6 支持
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} | grep 'disable_ipv6.*=.*1') ]]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*}
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
    fi

    # 调用 API、注册 WARP 账户
    warp_acc_register
}

warp_tool(){
    yellow "请选择需要使用的工具"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 获取 WARP+ Key ${YELLOW}(默认推荐)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 刷 WARP+ 账户流量 ${RED}(效率较低)${PLAIN}"
    echo ""
    read -p "请输入选项 [1-2]: " tool_choice
    if [[ $tool_choice == 2 ]]; then
        echo "ok"
    else
        warp_keygen
    fi
}

warp_keygen(){
    # 检测 python3 和 pip3 是否安装，如未安装则安装
    [[ -z $(type -P python3) ]] && [[ ! $SYSTEM == "CentOS" ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} python3 || ${PACKAGE_INSTALL[int]} python3

    # 下载生成器文件及依赖安装文件
    wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/24pbgen/main.py
    wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/24pbgen/requirements.txt

    # 安装依赖
    pip3 install -r requirements.txt

    # 运行程序，并输出结果
    python3 main.py

    # 删除文件
    rm -f main.py
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                ${RED}CloudFlare WARP 一键管理脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakanocchannel              #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoc                     #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WireGuard-WARP"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 WireGuard-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 启动、停止或重启 WARP"
    echo -e " ${GREEN}4.${PLAIN} 切换 WARP 账户类型"
    echo " -------------"
    echo -e " ${GREEN}5.${PLAIN} 获取 WARP+ Key、刷流量"
    echo -e " ${GREEN}6.${PLAIN} 从 GitLab 拉取最新脚本"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-6]: " menu_input
    case $menu_input in
        5 ) warp_tool ;;
        * ) exit 1 ;;
    esac
}

menu