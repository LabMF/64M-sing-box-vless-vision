# 64M sing-box VLESS + REALITY for Alpine

一个面向 **低内存 Alpine VPS / 容器** 的 sing-box VLESS + REALITY 安装与配置脚本。

适合这类环境：

- Alpine Linux
- 极低内存，例如 64M RAM
- 无法添加 swap
- 不适合在服务器上直接解压大型压缩包
- 想使用 sing-box + VLESS + REALITY + Vision

本项目脚本支持一级菜单：

```txt
1) 安装
2) 更新配置
3) 查看状态
0) 退出
```

选择「安装」或「更新配置」时，只需要输入两个项目：

```txt
监听端口
REALITY 域名 / SNI
```

默认值：

```txt
端口：443
域名：www.cloudflare.com
```

> 实测 `www.cloudflare.com` 作为 REALITY handshake / SNI 目标比 `www.bing.com` 更稳定。

---

## 项目地址

```txt
https://github.com/LabMF/64M-sing-box-vless-vision
```

安装脚本地址：

```txt
https://github.com/LabMF/64M-sing-box-vless-vision/blob/main/setup-singbox-reality.sh
```

服务器端请使用 raw 地址下载：

```txt
https://raw.githubusercontent.com/LabMF/64M-sing-box-vless-vision/main/setup-singbox-reality.sh
```

---

## 为什么 sing-box 二进制要本地解压后上传？

在 64M 内存且无法添加 swap 的 Alpine 系统中，直接在服务器上下载并解压 sing-box 压缩包，可能会触发 OOM，导致 SSH 断开或系统卡死。

因此推荐：

1. 在本地电脑下载 sing-box 的 Linux musl 版本；
2. 在本地电脑解压；
3. 只把解压出来的 `sing-box` 二进制上传到服务器；
4. 在 Alpine 服务器上直接从 GitHub 下载本项目脚本；
5. 运行脚本生成 VLESS + REALITY 配置。

脚本本身很小，可以直接在 Alpine 上下载；但 sing-box 压缩包不建议在 64M 小内存服务器上解压。

---

## 一、本地下载 sing-box musl 版本

以下示例适用于 `linux/amd64` 服务器。

如果服务器执行：

```sh
uname -m
```

输出：

```txt
x86_64
```

通常就应该下载 `amd64` 版本。

### macOS / Linux 本地执行

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

---

## 二、上传 sing-box 二进制到服务器

把 `你的服务器IP` 换成你的 VPS IP：

```sh
scp ./sing-box root@你的服务器IP:/root/sing-box
```

如果 SSH 端口不是 22，例如 2222：

```sh
scp -P 2222 ./sing-box root@你的服务器IP:/root/sing-box
```

---

## 三、在 Alpine 服务器上下载本项目安装脚本

SSH 登录服务器：

```sh
ssh root@你的服务器IP
```

在服务器上执行：

```sh
wget -O /root/setup-singbox-reality.sh \
  https://raw.githubusercontent.com/LabMF/64M-sing-box-vless-vision/main/setup-singbox-reality.sh

chmod +x /root/setup-singbox-reality.sh
```

如果你的 Alpine 没有 `wget`，可以尝试：

```sh
curl -L -o /root/setup-singbox-reality.sh \
  https://raw.githubusercontent.com/LabMF/64M-sing-box-vless-vision/main/setup-singbox-reality.sh

chmod +x /root/setup-singbox-reality.sh
```

如果 `curl` 也没有，建议先检查系统是否自带 BusyBox wget：

```sh
busybox wget -O /root/setup-singbox-reality.sh \
  https://raw.githubusercontent.com/LabMF/64M-sing-box-vless-vision/main/setup-singbox-reality.sh

chmod +x /root/setup-singbox-reality.sh
```

---

## 四、运行脚本

```sh
sh /root/setup-singbox-reality.sh
```

你会看到菜单：

```txt
==============================================
 sing-box VLESS + REALITY for Alpine
==============================================
 1) 安装
 2) 更新配置
 3) 查看状态
 0) 退出
==============================================
请选择:
```

首次使用请选择：

```txt
1) 安装
```

然后输入：

```txt
监听端口
REALITY 域名 / SNI
```

推荐直接使用默认值：

```txt
端口：443
域名：www.cloudflare.com
```

如果你要自定义端口，例如 `8443`，记得云服务器安全组 / 防火墙也要放行对应 TCP 端口。

---

## 五、安装完成后的节点信息

脚本执行完成后，会输出 VLESS 分享链接，并保存到：

```sh
/root/singbox-vless-reality-info.txt
```

查看：

```sh
cat /root/singbox-vless-reality-info.txt
```

里面会包含：

```txt
Address
Port
UUID
Flow
SNI
PublicKey
ShortId
Client link
```

直接复制 `Client link` 下面的 `vless://...` 链接导入客户端即可。

---

## 六、更新配置

如果需要修改端口或域名，再次运行脚本：

```sh
sh /root/setup-singbox-reality.sh
```

选择：

```txt
2) 更新配置
```

然后重新输入端口和域名。

注意：更新配置会重新生成：

- UUID
- REALITY private / public key
- short_id
- 客户端链接

更新后旧节点会失效，需要重新导入新的 `vless://` 链接。

---

## 七、客户端参数

如果客户端无法正确导入链接，可以手动填写：

```txt
协议：VLESS
地址：服务器 IP
端口：脚本中输入的端口
传输：TCP
TLS / Security：REALITY
SNI / serverName：脚本中输入的域名，例如 www.cloudflare.com
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

如果导入后无法连接，请打开节点详情，重点检查：

```txt
flow=xtls-rprx-vision
pbk
sid
sni
fp=chrome
```

---

## 八、服务管理

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

如果没有 `ss`，可以尝试：

```sh
netstat -lntp | grep sing-box
```

---

## 九、日志排查

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

---

## 十、常见问题

### 1. `/usr/local/bin/sing-box: not found`

如果文件明明存在，但运行时报：

```txt
-sh: /usr/local/bin/sing-box: not found
```

通常说明上传的不是 musl 版本，或者架构不匹配。

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

先检查服务是否监听：

```sh
rc-service sing-box status
ss -lntp | grep sing-box
```

再看日志：

```sh
tail -f /var/log/sing-box/sing-box.log /var/log/sing-box/error.log
```

如果日志只出现大量 SNI 域名，例如：

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

也可以测试服务器是否能访问目标域名：

```sh
wget -S --spider https://www.cloudflare.com 2>&1 | head -30
```

### 4. 日志来源显示为 `10.x.x.x`

如果日志显示来源类似：

```txt
10.91.0.1
```

说明 Alpine 可能运行在容器或 NAT 后面。只要端口是纯 TCP 透传，通常没问题。

但如果前面有 HTTPS 反代、TLS 终止、Cloudflare 代理等，会导致 REALITY 握手失败。REALITY 需要原始 TCP/TLS ClientHello 直达 sing-box。

---

## 十一、卸载

```sh
rc-service sing-box stop 2>/dev/null || true
rc-update del sing-box default 2>/dev/null || true
rm -f /etc/init.d/sing-box
rm -f /usr/local/bin/sing-box
rm -rf /usr/local/etc/sing-box
rm -rf /var/log/sing-box
rm -f /root/singbox-vless-reality-info.txt
```

---

## 默认路径

```txt
上传的二进制：/root/sing-box
安装后的二进制：/usr/local/bin/sing-box
配置文件：/usr/local/etc/sing-box/config.json
节点信息：/root/singbox-vless-reality-info.txt
日志：/var/log/sing-box/
服务：/etc/init.d/sing-box
```

---

## 免责声明

请仅在你拥有管理权限的服务器和合法网络环境中使用。
