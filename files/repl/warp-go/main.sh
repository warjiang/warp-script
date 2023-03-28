#!/bin/sh

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
yellow "获取 CloudFlare WARP 账号密钥信息方法: "
green "电脑: 下载并安装 CloudFlare WARP → 设置 → 偏好设置 → 账户 →复制密钥到脚本中"
green "手机: 下载并安装 1.1.1.1 APP → 菜单 → 账户 → 复制密钥到脚本中"
echo ""
yellow "重要：请确保手机或电脑的 1.1.1.1 APP 的账户状态为WARP+！"
echo ""
yellow "如没有 WARP 账户许可证密钥，直接回车即可！"
echo ""
read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
  red "WARP 账户许可证密钥格式输入错误，请重新输入！"
  read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
done
if [[ -n $warpkey ]]; then
  read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " devicename
  /opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf --license=$warpkey --device-name=$devicename
else
  red "未输入 WARP 账户许可证密钥，将使用 WARP 免费账户"
  ./warp-go --register --config=warp.conf
fi

./warp-go --config=warp.conf --export-wireguard=proxy.conf

clear
green "WARP-GO 的 WireGuard 配置文件已生成成功！"
yellow "下面是配置文件内容："
cat proxy.conf
echo ""
yellow "下面是配置文件分享二维码："
qrencode -t ansiutf8 < proxy.conf
echo ""
yellow "请在本地使用此方法：https://blog.misaka.rest/2023/03/12/cf-warp-yxip/ 优选可用的 Endpoint IP"