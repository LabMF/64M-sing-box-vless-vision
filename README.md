# 64M-sing-box-vless-vision
# sing-box VLESS + REALITY for Alpine

一个面向低内存 Alpine VPS / 容器的小脚本，用于安装并配置：

- sing-box
- VLESS
- REALITY
- TCP
- Vision：`xtls-rprx-vision`
- OpenRC 服务管理

本项目的设计目标是适配非常小内存的 Alpine 系统，例如 64M RAM 且无法添加 swap 的环境。

## 为什么要本地解压再上传？

很多低内存 Alpine VPS 在服务器端下载并解压 sing-box / Xray 压缩包时容易触发 OOM，导致 SSH 断开或服务卡死。

因此推荐流程是：

1. 在本地电脑下载 sing-box 的 Linux musl 版本；
2. 在本地电脑解压；
3. 只把解压出来的 `sing-box` 二进制上传到服务器；
4. 在服务器端运行本脚本生成配置和服务。

musl 版本适合 Alpine。

## 服务器要求

- Alpine Linux
- root 权限
- OpenRC
- 已上传 sing-box musl 二进制到 `/root/sing-box`

脚本默认不会在服务器上下载或解压 sing-box。

## 一、本地下载 sing-box musl 版本

以下示例适用于 `linux/amd64` 服务器。

如果你的服务器是 `x86_64`，通常就是 `amd64`。

### macOS / Linux

```sh
mkdir -p ~/singbox-upload
cd ~/singbox-upload

VERSION=1.13.12
ARCH=amd64

curl -L -o sing-box-${VERSION}-linux-${ARCH}-musl.tar.gz \
  https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${ARCH}-musl.tar.gz

tar -xzf sing-box-${VERSION}-linux-${ARCH}-musl.tar.gz

cp sing-box-${VERSION}-linux-${ARCH}-musl/sing-box ./sing-box

chmod +x ./sing-box

ls -lh ./sing-box
file ./sing-box
```

正常情况下，`file ./sing-box` 应显示类似：

```txt
ELF 64-bit LSB executable, x86-64
```

### Windows

在浏览器下载：

```txt
https://github.com/SagerNet/sing-box/releases/download/v1.13.12/sing-box-1.13.12-linux-amd64-musl.tar.gz
```

使用 7-Zip 解压两次，最后得到 `sing-box` 文件。

## 二、上传到服务器

```sh
scp ./sing-box root@你的服务器IP:/root/sing-box
```

如果 SSH 端口不是 22，例如 2222：

```sh
scp -P 2222 ./sing-box root@你的服务器IP:/root/sing-box
```

## 三、上传并运行脚本

把 `setup-singbox-reality.sh` 上传到服务器：

```sh
scp ./setup-singbox-reality.sh root@你的服务器IP:/root/setup-singbox-reality.sh
```

登录服务器：

```sh
ssh root@你的服务器IP
```

赋予执行权限：

```sh
chmod +x /root/setup-singbox-reality.sh
```

运行：

```sh
sh /root/setup-singbox-reality.sh
```

脚本会显示一级菜单：

```txt
1) 安装
2) 更新配置
3) 查看状态
0) 退出
```

无论选择「安装」还是「更新配置」，都会让你输入两个项目：

1. 监听端口
2. REALITY 域名 / SNI

默认值：

```txt
端口：443
域名：www.cloudflare.com
```

> 实测 `www.cloudflare.com` 比 `www.bing.com` 更稳定。如果使用其他域名，需要确认服务器本身能访问该域名的 443 端口。

## 四、安装模式

选择：

```txt
1) 安装
```

脚本会执行：

- 安装 `/root/sing-box` 到 `/usr/local/bin/sing-box`
- 生成 UUID
- 生成 REALITY private/public key
- 生成 short_id
- 写入 `/usr/local/etc/sing-box/config.json`
- 写入 OpenRC 服务 `/etc/init.d/sing-box`
- 启动 sing-box
- 输出 VLESS 分享链接

节点信息会保存到：

```sh
/root/singbox-vless-reality-info.txt
```

查看：

```sh
cat /root/singbox-vless-reality-info.txt
```

## 五、更新配置模式

选择：

```txt
2) 更新配置
```

脚本会重新生成：

- UUID
- REALITY keypair
- short_id
- 配置文件
- 客户端链接

适用于修改端口或域名。

注意：更新配置后，旧客户端链接会失效，需要重新导入新的 `vless://` 链接。

## 六、客户端参数

客户端导入脚本输出的 `vless://` 链接即可。

如果手动填写，请确认：

```txt
协议：VLESS
地址：服务器 IP
端口：你输入的端口
传输：TCP
TLS / Security：REALITY
SNI / serverName：你输入的域名，例如 www.cloudflare.com
PublicKey / pbk：脚本输出的 PublicKey
ShortId / sid：脚本输出的 ShortId
Flow：xtls-rprx-vision
Fingerprint：chrome
ALPN：留空
```

推荐客户端：

- v2rayN
- v2rayNG
- NekoBox
- Shadowrocket
- sing-box 客户端

如果某个客户端导入后无法连接，请打开节点详情，确认 `flow=xtls-rprx-vision`、`pbk`、`sid`、`sni` 没有丢失。

## 七、服务管理

查看状态：

```sh
rc-service sing-box status
```

重启：

```sh
rc-service sing-box restart
```

停止：

```sh
rc-service sing-box stop
```

查看监听端口：

```sh
ss -lntp | grep sing-box
```

如果没有 `ss`，可尝试：

```sh
netstat -lntp | grep sing-box
```

## 八、日志排查

查看日志：

```sh
tail -f /var/log/sing-box/sing-box.log /var/log/sing-box/error.log
```

临时开启 debug：

```sh
sed -i 's/"level": "warn"/"level": "debug"/' /usr/local/etc/sing-box/config.json
rc-service sing-box restart
tail -f /var/log/sing-box/sing-box.log
```

恢复 warn：

```sh
sed -i 's/"level": "debug"/"level": "warn"/' /usr/local/etc/sing-box/config.json
rc-service sing-box restart
```

## 九、常见问题

### 1. `/usr/local/bin/sing-box: not found`

如果文件明明存在，但运行时报：

```txt
-sh: /usr/local/bin/sing-box: not found
```

通常说明你上传的不是 musl 版本，或者架构不匹配。

请确认下载的是：

```txt
sing-box-1.13.12-linux-amd64-musl.tar.gz
```

并在服务器检查：

```sh
uname -m
ls -lh /root/sing-box /usr/local/bin/sing-box
```

### 2. 服务启动了，但客户端无法连接

先看服务是否监听：

```sh
rc-service sing-box status
ss -lntp | grep sing-box
```

再看日志：

```sh
tail -f /var/log/sing-box/sing-box.log /var/log/sing-box/error.log
```

如果日志只出现大量访问 SNI 域名，例如：

```txt
dns: lookup domain www.cloudflare.com
```

但没有真实访问目标，例如 `google.com`，通常是客户端 REALITY 参数没有匹配。

重点检查：

```txt
pbk
sid
sni
flow=xtls-rprx-vision
fp=chrome
```

### 3. `www.bing.com` 无法使用

部分环境下，`www.bing.com` 作为 REALITY handshake 目标可能不稳定。

推荐使用：

```txt
www.cloudflare.com
```

你也可以测试服务器是否能访问目标域名：

```sh
wget -S --spider https://www.cloudflare.com 2>&1 | head -30
```

### 4. 连接请求来源显示为 `10.x.x.x`

如果日志显示来源是类似：

```txt
10.91.0.1
```

说明 Alpine 可能运行在容器或 NAT 后面。只要端口是纯 TCP 透传，通常没问题。

但如果前面有 HTTPS 反代、TLS 终止、Cloudflare 代理等，会导致 REALITY 握手失败。REALITY 需要原始 TCP/TLS ClientHello 直达 sing-box。

## 十、卸载

```sh
rc-service sing-box stop 2>/dev/null || true
rc-update del sing-box default 2>/dev/null || true
rm -f /etc/init.d/sing-box
rm -f /usr/local/bin/sing-box
rm -rf /usr/local/etc/sing-box
rm -rf /var/log/sing-box
rm -f /root/singbox-vless-reality-info.txt
```

## 默认配置路径

```txt
二进制：/usr/local/bin/sing-box
配置文件：/usr/local/etc/sing-box/config.json
节点信息：/root/singbox-vless-reality-info.txt
日志：/var/log/sing-box/
服务：/etc/init.d/sing-box
```

## 免责声明

请仅在你拥有管理权限的服务器和合法网络环境中使用。
