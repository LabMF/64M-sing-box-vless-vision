# Alpine 极低内存 VLESS-Reality-Vision 一键安装脚本

这是一个面向 **Alpine Linux 极低内存 VPS** 的 `sing-box` 一键安装脚本，核心思路保持简单直接：

1. 向 `/etc/apk/repositories` 添加 Alpine `edge/main` 与 `edge/community` 仓库；
2. 执行 `apk update`；
3. 通过 `apk add --no-cache sing-box curl openssl` 安装必要组件；
4. 自动生成 VLESS + Reality + Vision 配置；
5. 创建 OpenRC 服务并设置开机自启。

适合 **128M 内存、专机专用、只用于搭建代理服务** 的 Alpine 系统。

---

## 特性

- 使用 Alpine `apk` 直接安装 `sing-box`
- 不依赖 `jq`、`bash`、`python` 等额外工具
- 自动添加 `edge/main` 与 `edge/community` 仓库
- 自动生成 UUID
- 自动生成 Reality Private Key / Public Key
- 自动生成 Short ID
- 默认启用 VLESS + Reality + Vision
- 自动创建 OpenRC 服务
- 自动设置开机启动
- 自动输出客户端链接
- 支持卸载

---

## 系统要求

- Alpine Linux
- root 权限
- OpenRC 环境
- 建议内存：128M 及以上
- 建议用途：专机专用代理服务

默认监听端口为 `443`，请确保服务器安全组或防火墙已放行 TCP 443。

---

## 一键安装

把下面的地址替换成你自己的 GitHub Raw 地址后执行：

```sh
wget -O install.sh https://raw.githubusercontent.com/你的用户名/你的仓库名/main/install.sh
sh install.sh
```

或者：

```sh
wget -O - https://raw.githubusercontent.com/你的用户名/你的仓库名/main/install.sh | sh
```

---

## 自定义参数

脚本支持通过环境变量修改默认参数。

### 修改 SNI

默认 SNI 为：

```txt
www.bing.com
```

自定义：

```sh
SNI=www.microsoft.com sh install.sh
```

### 修改端口

默认端口为：

```txt
443
```

自定义：

```sh
PORT=8443 sh install.sh
```

### 修改监听地址

默认监听：

```txt
::
```

这通常可以同时监听 IPv6 和 IPv4。如果你的机器 IPv6 支持有问题，可以改为：

```sh
LISTEN=0.0.0.0 sh install.sh
```

### 同时自定义

```sh
PORT=443 SNI=www.bing.com LISTEN='::' sh install.sh
```

---

## 安装完成后

安装完成后，脚本会输出类似下面的信息：

```txt
SNI: www.bing.com
PORT: 443
UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Public Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Short ID: xxxxxxxxxxxxxxxx

客户端链接：
vless://...
```

连接信息也会保存到：

```sh
/root/vless-reality-info.txt
```

查看客户端链接：

```sh
cat /root/vless-reality-info.txt
```

客户端链接中的 `你的服务器IP` 需要手动替换成你的 VPS 公网 IP。

---

## 常用命令

### 查看服务状态

```sh
rc-service sing-box status
```

### 重启服务

```sh
rc-service sing-box restart
```

### 停止服务

```sh
rc-service sing-box stop
```

### 查看日志

```sh
cat /var/log/sing-box.log
cat /var/log/sing-box.err
```

### 检查配置

```sh
sing-box check -c /etc/sing-box/config.json
```

### 查看内存占用

```sh
ps -o pid,rss,comm -p $(pgrep sing-box)
```

---

## 配置文件位置

```sh
/etc/sing-box/config.json
```

服务文件位置：

```sh
/etc/init.d/sing-box
```

连接信息位置：

```sh
/root/vless-reality-info.txt
```

---

## 卸载

```sh
sh install.sh uninstall
```

卸载会删除：

- OpenRC 服务
- `/etc/sing-box`
- `/root/vless-reality-info.txt`
- `/var/lib/sing-box`
- sing-box 软件包

注意：卸载不会自动删除你添加到 `/etc/apk/repositories` 的 edge 仓库。如需删除，请手动编辑：

```sh
vi /etc/apk/repositories
```

---

## 脚本执行的核心步骤

脚本保留了原来的安装思路：

```sh
cat >> /etc/apk/repositories << EOF_REPO
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
EOF_REPO

apk update
apk add --no-cache sing-box curl openssl
```

在此基础上，脚本额外做了：

- 避免重复添加相同仓库
- 自动生成 Reality 密钥
- 自动生成 sing-box 配置
- 自动创建 OpenRC 服务
- 自动保存客户端链接
- 自动检查配置是否可用

---

## 客户端参数说明

| 参数 | 值 |
| --- | --- |
| 协议 | VLESS |
| 传输 | TCP |
| TLS | Reality |
| Flow | xtls-rprx-vision |
| Fingerprint | chrome |
| SNI | 默认 `www.bing.com` |
| 端口 | 默认 `443` |
| UUID | 脚本自动生成 |
| Public Key | 脚本自动生成 |
| Short ID | 脚本自动生成 |

---

## 注意事项

1. 本脚本会直接向 `/etc/apk/repositories` 添加 Alpine edge 仓库。
2. 该方式适合专机专用代理服务，不建议在生产业务服务器上混用。
3. 如果 443 端口被占用，请使用 `PORT=其他端口 sh install.sh`。
4. 如果 `listen: ::` 在你的 VPS 上无法正常监听，请使用 `LISTEN=0.0.0.0 sh install.sh`。
5. Reality 的 SNI 建议使用常见大型站点域名，例如 `www.bing.com`。

---

## License

MIT
