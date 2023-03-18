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

# 检查系统内核版本
main=$(uname -r | awk -F . '{print $1}')
minor=$(uname -r | awk -F . '{print $2}')
# 获取系统版本号
OSID=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
# 检查VPS虚拟化
VIRT=$(systemd-detect-virt)

# 删除 WGCF 默认配置文件中的监听 IP
wg1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf" # IPv4
wg2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf" # IPv6

# 设置 WGCF 配置文件的 DNS 服务器
wg3="sed -i 's/1.1.1.1/1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
wg4="sed -i 's/1.1.1.1/2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"

# 设置允许外部 IP 访问
wg5='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf' # IPv4
wg6='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf' # IPv6
wg7='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf' # 双栈

# 设置 WARP-GO 配置文件的监听 IP
wgo1='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0#g" /opt/warp-go/warp.conf' # IPv4
wgo2='sed -i "s#.*AllowedIPs.*#AllowedIPs = ::/0#g" /opt/warp-go/warp.conf' # IPv6
wgo3='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0,::/0#g" /opt/warp-go/warp.conf' # 双栈

# 设置允许外部 IP 访问
wgo4='sed -i "s#.*PostUp.*#PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main#g;s#.*PostDown.*#PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main#g" /opt/warp-go/warp.conf' # IPv4
wgo5='sed -i "s#.*PostUp.*#PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g;s#.*PostDown.*#PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g" /opt/warp-go/warp.conf' # IPv6
wgo6='sed -i "s#.*PostUp.*#PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main; ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g;s#.*PostDown.*#PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main; ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g" /opt/warp-go/warp.conf' # 双栈

# 检测 VPS 处理器架构
archAffix(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

# 检测 VPS 的出站 IP
check_ip(){
    ipv4=$(curl -s4m8 ip.p3terx.com | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com | sed -n 1p)
}

# 检查 VPS 的 IP 形式
check_stack(){
    lan4=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    lan6=$(ip route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+')
    if [[ "$lan4" =~ ^([0-9]{1,3}\.){3} ]]; then
        ping -c2 -W3 1.1.1.1 >/dev/null 2>&1 && out4=1
    fi
    if [[ "$lan6" != "::1" && "$lan6" =~ ^([a-f0-9]{1,4}:){2,4}[a-f0-9]{1,4} ]]; then
        ping6 -c2 -w10 2606:4700:4700::1111 >/dev/null 2>&1 && out6=1
    fi
}

# 检测 VPS 的 WARP 状态
check_warp(){
    warp_v4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warp_v6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

# 检测 WARP+ 账户流量情况
check_quota(){
    if [[ "$CHECK_TYPE" = 1 ]]; then
        # 如为WARP-Cli，使用其自带接口获取流量
        QUOTA=$(warp-cli --accept-tos account 2>/dev/null | grep -oP 'Quota: \K\d+')
    else
        # 判断为 WGCF 或 WARP-GO，从客户端相应的配置文件中提取
        if [[ -a "/opt/warp-go/warp-go" ]]; then
            ACCESS_TOKEN=$(grep 'Token' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
            DEVICE_ID=$(grep 'Device' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
        fi
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            ACCESS_TOKEN=$(grep 'access_token' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
            DEVICE_ID=$(grep 'device_id' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
        fi

        # 使用API，获取流量信息
        API=$(curl -s "https://api.cloudflareclient.com/v0a884/reg/$DEVICE_ID" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $ACCESS_TOKEN")
        QUOTA=$(grep -oP '"quota":\K\d+' <<< $API)
    fi

    # 流量单位换算
    [[ $QUOTA -gt 10000000000000 ]] && QUOTA="$(echo "scale=2; $QUOTA/1000000000000" | bc) TB" || QUOTA="$(echo "scale=2; $QUOTA/1000000000" | bc) GB"
}

# 检查 TUN 模块是否开启
check_tun(){
    TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')
    if [[ ! $TUN =~ "in bad state"|"处于错误状态"|"ist in schlechter Verfassung" ]]; then
        if [[ $VIRT == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "检测到目前VPS未开启TUN模块, 请到后台控制面板处开启"
                exit 1
            else
                return 0
            fi
        elif [[ $VIRT == "openvz" ]]; then
            wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/tun.sh && bash tun.sh
        else
            red "检测到目前VPS未开启TUN模块, 请到后台控制面板处开启"
            exit 1
        fi
    fi
}

# 检查适合 VPS 的最佳 MTU 值
check_mtu(){
    yellow "正在检测并设置 MTU 最佳值, 请稍等..."
    check_ip
    MTUy=1500
    MTUc=10
    if [[ -n ${ipv6} && -z ${ipv4} ]]; then
        ping='ping6'
        IP1='2606:4700:4700::1001'
        IP2='2001:4860:4860::8888'
    else
        ping='ping'
        IP1='1.1.1.1'
        IP2='8.8.8.8'
    fi
    while true; do
        if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
            MTUc=1
            MTUy=$((${MTUy} + ${MTUc}))
        else
            MTUy=$((${MTUy} - ${MTUc}))
            if [[ ${MTUc} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTUy} -le 1360 ]]; then
            MTUy='1360'
            break
        fi
    done
    # 将 MTU 最佳值放置至 MTU 变量中备用
    MTU=$((${MTUy} - 80))
    
    if [[ -a "/opt/warp-go/warp-go" ]]; then
        sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf
    fi
    green "MTU 最佳值 = $MTU 已设置完毕！"
}

# 检查适合 VPS 的最佳 Endpoint IP 地址
check_endpoint(){
    yellow "正在检测并设置最佳 Endpoint IP 地址，请稍等，大约需要 1-2 分钟..."

    # 下载优选工具软件，感谢某匿名网友的分享的优选工具
    wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-$(archAffix) -O warp >/dev/null 2>&1

    # 根据 VPS 的出站 IP 情况，生成对应的优选 Endpoint IP 段列表
    check_ip

    if [[ -n $ipv4 ]]; then
        n=0
        iplist=100
        while true; do
            temp[$n]=$(echo 162.159.192.$(($RANDOM%256)))
            n=$[$n+1]
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.193.$(($RANDOM%256)))
            n=$[$n+1]
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.195.$(($RANDOM%256)))
            n=$[$n+1]
            if [ $n -ge $iplist ]; then
                break
            fi
        done
        while true; do
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.192.$(($RANDOM%256)))
                n=$[$n+1]
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.193.$(($RANDOM%256)))
                n=$[$n+1]
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.195.$(($RANDOM%256)))
                n=$[$n+1]
            fi
        done
    else
        n=0
        iplist=100
        while true; do
            temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2)))])
            n=$[$n+1]
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2)))])
            n=$[$n+1]
            if [ $n -ge $iplist ]; then
                break
            fi
        done
        while true; do
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2)))])
                n=$[$n+1]
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2))):$(printf '%x\n' $(($RANDOM*2+$RANDOM%2)))])
                n=$[$n+1]
            fi
        done
    fi

    # 将生成的 IP 段列表放到 ip.txt 里，待程序优选
    echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u > ip.txt
    
    # 取消 Linux 自带的线程限制，以便生成优选 Endpoint IP
    ulimit -n 102400

    # 启动 WARP Endpoint IP 优选工具
    chmod +x warp && ./warp >/dev/null 2>&1

    # 将 result.csv 文件的优选 Endpoint IP 提取出来，放置到 best_endpoint 变量中备用
    best_endpoint=$(cat result.csv | sed -n 2p | awk -F ',' '{print $1}')

    # 删除 WARP Endpoint IP 优选工具及其附属文件
    rm -f warp ip.txt result.csv

    green "Endpoint IP 最佳值 = $best_endpoint 已设置完毕！"
}

# 选择 WGCF 安装 / 切换模式
select_wgcf(){
    yellow "请选择 WGCF 安装/切换的模式"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 Wgcf-WARP 单栈模式 ${YELLOW}(IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 / 切换 Wgcf-WARP 单栈模式 ${YELLOW}(IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 Wgcf-WARP 双栈模式"
    echo ""
    read -p "请输入选项 [1-3]: " wgcf_mode
    if [ "$wgcf_mode" = "1" ]; then
        install_wgcf_ipv4
    elif [ "$wgcf_mode" = "2" ]; then
        install_wgcf_ipv6
    elif [ "$wgcf_mode" = "3" ]; then
        install_wgcf_dual
    else
        red "输入错误，请重新输入"
        select_wgcf
    fi
}

install_wgcf_ipv4(){
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-gp
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WGCF 和 WARP-GO 冲突，故检测 WARP-GO 之后打断安装
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO 已安装，请先卸载 WARP-GO"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg2 && wgcf2=$wg3 && wgcf3=$wg5
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg2 && wgcf2=$wg4
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wgcf1=$wg2 && wgcf2=$wg3 && wgcf3=$wg5
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg2 && wgcf2=$wg4 && wgcf3=$wg5
    fi

    # 检测是否安装 WGCF，如安装，则切换配置文件。反之执行安装操作
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

install_wgcf_ipv6(){
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-gp
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WGCF 和 WARP-GO 冲突，故检测 WARP-GO 之后打断安装
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO 已安装，请先卸载 WARP-GO"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg1 && wgcf2=$wg3
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg1 && wgcf2=$wg4 && wgcf3=$wg6
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wgcf1=$wg1 && wgcf2=$wg3 && wgcf3=$wg6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg1 && wgcf2=$wg4 && wgcf3=$wg6
    fi

    # 检测是否安装 WGCF，如安装，则切换配置文件。反之执行安装操作
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

install_wgcf_dual(){
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-gp
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WGCF 和 WARP-GO 冲突，故检测 WARP-GO 之后打断安装
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO 已安装，请先卸载 WARP-GO"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg3 && wgcf2=$wg5
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg4 && wgcf2=$wg6
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wgcf1=$wg3 && wgcf2=$wg7
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg4 && wgcf2=$wg6
    fi

    # 检测是否安装 WGCF，如安装，则切换配置文件。反之执行安装操作
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

# 下载 WGCF
init_wgcf(){
    wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wgcf/wgcf-latest-linux-$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
}

# 利用 WGCF 注册 CloudFlare WARP 账户
register_wgcf(){
    # 如已注册 WARP 账户，则自动拉取。避免造成 CloudFlare 服务器负担
    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
    fi

    # 注册 WARP 账户，直到注册成功为止
    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如提示429 Too Many Requests错误请耐心等待脚本重试注册即可"
        wgcf register --accept-tos
        sleep 5
    done
    chmod +x wgcf-account.toml

    # 生成 WireGuard 配置文件
    wgcf generate && chmod +x wgcf-profile.conf
}

# 配置 WGCF 的 WireGuard 配置文件
conf_wgcf(){
    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
}

# 检查 WGCF 是否启动成功，如未启动成功则提示
check_wgcf(){
    yellow "正在启动 WGCF-WARP"
    i=0
    while [ $i -le 4 ]; do let i++
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        check_warp
        if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
            green "WGCF-WARP 已启动成功！"
            break
        else
            red "WGCF-WARP 启动失败！"
        fi

        check_warp
        if [[ ! $warp_v4 =~ on|plus && ! $warp_v6 =~ on|plus ]]; then
            wg-quick down wgcf >/dev/null 2>&1
            red "安装 WGCF-WARP 失败！"
            green "建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
            yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁，请卸载 WGCF ，然后使用 WARP-GO 重试"
            exit 1
        fi
    done
}

install_wgcf(){
    # 检测系统要求，如未达到要求则打断安装
    [[ $SYSTEM == "CentOS" ]] && [[ ${OSID} -lt 7 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 7及以上版本的系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ${OSID} -lt 10 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Debian 10及以上版本的系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && [[ ${OSID} -lt 29 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Fedora 29及以上版本的系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ${OSID} -lt 18 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Ubuntu 16.04及以上版本的系统" && exit 1

    # 检测 TUN 模块是否开启
    check_tun

    # 安装 WGCF 必需依赖
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl lsb-release bc htop screen python3 inetutils-ping qrencode
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop screen python3 inetutils-ping qrencode
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi

    # 如 Linux 系统内核版本 < 5.6，或为 OpenVZ / LXC 虚拟化架构的VPS，则安装 Wireguard-GO
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wireguard-go/wireguard-go-$(archAffix) -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    # 下载并安装 WGCF
    init_wgcf

    # 在 WGCF 处注册账户
    register_wgcf

    # 检测 /etc/wireguard 文件夹是否创建，如未创建则创建一个
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi
    
    # 移动对应的配置文件，避免用户删除
    cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    # 设置 WGCF 的 WireGuard 配置文件
    conf_wgcf

    # 检查最佳 MTU 值，并应用至 WGCF 配置文件
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /etc/wireguard/wgcf.conf

    # 优选 EndPoint IP，并应用至 WGCF 配置文件
    check_endpoint
    sed -i "s/engage.cloudflareclient.com:2408/$best_endpoint/g" /etc/wireguard/wgcf.conf

    # 启动 WGCF，并检查 WGCF 是否启动成功
    check_wgcf
}


switch_wgcf_conf(){
    # 关闭 WGCF
    wg-quick down wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null

    # 删除配置好的 WGCF WireGuard 配置文件，并重新从 wgcf-profile.conf 拉取
    rm -rf /etc/wireguard/wgcf.conf
    cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1

    # 设置 WGCF 的 WireGuard 配置文件
    conf_wgcf

    # 检查最佳 MTU 值，并应用至 WGCF 配置文件
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /etc/wireguard/wgcf.conf

    # 优选 EndPoint IP，并应用至 WGCF 配置文件
    check_endpoint
    sed -i "s/engage.cloudflareclient.com:2408/$best_endpoint/g" /etc/wireguard/wgcf.conf

    # 启动 WGCF，并检查 WGCF 是否启动成功
    check_wgcf
}

# 卸载 WGCF
uninstall_wgcf(){
    # 关闭 WGCF
    wg-quick down wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null

    # 卸载 WireGuard 依赖
    ${PACKAGE_UNINSTALL[int]} wireguard-tools

    # 因为 WireProxy 需要依赖 WGCF，如未检测到，则删除账户信息文件
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-profile.toml
        rm -f /etc/wireguard/wgcf-account.toml
    fi

    # 删除 WGCF WireGuard 配置文件
    rm -f /etc/wireguard/wgcf.conf

    # 如有 WireGuard-GO，则删除
    rm -f /usr/bin/wireguard-go

    # 恢复 VPS 默认的出站规则
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi

    green "Wgcf-WARP 已彻底卸载成功!"
}

menu(){
    clear
    echo "#############################################################"
    echo -e "#                ${RED}CloudFlare WARP 一键管理脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misaka_noc                    #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misaka_noc_chat               #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WGCF-WARP"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 WGCF-WARP${PLAIN}"
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
    read -rp "请输入选项 [0-13]: " menu_input
    case $menu_input in
        1 ) select_wgcf ;;
        2 ) uninstall_wgcf ;;
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