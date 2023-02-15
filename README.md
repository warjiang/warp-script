# warp-script

CloudFlare WARP 一键管理脚本

## 脚本地址

```shell
wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/warp.sh && bash warp.sh
```

## 常见问题

待收集汇总补充

### 1. Wgcf 或 WARP-GO？

Wgcf 和 WARP-GO 都是第三方的 CloudFlare WARP 的 Linux 应用程序。由于 Wgcf 在香港、美西区域遭到 CloudFlare 的官方限制，故只能使用 WARP-GO

对于大部分区域的建议：Wgcf > WARP-GO

### 2. 在 vpsfree.es 安装 Wgcf-WARP

运行本脚本代码安装WARP之后，由于EndPoint不清楚是上游原因还是啥情况被屏蔽了，需要修改EndPoint以使用

下面是一键修改命令：

```shell
wg-quick down wgcf
echo "Endpoint = [2001:67c:2b0:db32:0:1:a29f:c001]:2408" >> /etc/wireguard/wgcf.conf
wg-quick up wgcf
curl -4 ip.p3terx.com
```

待出现104或8开头的IP即为成功

## 鸣谢项目

* Fscarmen：https://github.com/fscarmen/warp
* CloudFlare WARP：https://one.one.one.one/
* Wgcf：https://github.com/ViRb3/wgcf
* WARP-GO：https://gitlab.com/ProjectWARP/warp-go

## 赞助

爱发电：https://afdian.net/a/Misaka-blog

![afdian-MisakaNo の 小破站](https://user-images.githubusercontent.com/122191366/211533469-351009fb-9ae8-4601-992a-abbf54665b68.jpg)