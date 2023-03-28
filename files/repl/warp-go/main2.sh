#!/bin/sh

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

rm -f warp.conf proxy.conf

chmod +x ./warp-go
clear
yellow "请选择需要使用的 WARP 账户类型"
echo ""
echo -e " ${GREEN}1.${PLAIN} WARP 免费账户 ${YELLOW}(默认)${PLAIN}"
echo -e " ${GREEN}2.${PLAIN} WARP+"
echo -e " ${GREEN}3.${PLAIN} WARP Teams"
echo ""
read -p "请输入选项 [1-3]: " account_type
if [[ $account_type == 2 ]]; then
  yellow "获取 CloudFlare WARP 账号密钥信息方法: "
  green "电脑: 下载并安装 CloudFlare WARP → 设置 → 偏好设置 → 账户 →复制密钥到脚本中"
  green "手机: 下载并安装 1.1.1.1 APP → 菜单 → 账户 → 复制密钥到脚本中"
  echo ""
  yellow "重要：请确保手机或电脑的 1.1.1.1 APP 的账户状态为WARP+！"
  echo ""
  read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
  until [[ $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
    red "WARP 账户许可证密钥格式输入错误，请重新输入！"
    read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
  done
  read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " devicename
  /opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf --license=$warpkey --device-name=$devicename
elif [[ $account_type == 3 ]]; then
  echo "ok"
else
  echo "ok"
fi