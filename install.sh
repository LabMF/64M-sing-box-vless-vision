#!/bin/sh
# Alpine 极低内存 VLESS-Reality-Vision 一键安装脚本
# 思路：直接添加 Alpine edge/main + edge/community，然后通过 apk 安装 sing-box。
# 适合 128M 内存、专机专用代理服务场景。

set -eu

CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
INFO_FILE="/root/vless-reality-info.txt"
REPO_FILE="/etc/apk/repositories"
SERVICE_FILE="/etc/init.d/sing-box"

# 可通过环境变量覆盖：
#   PORT=443 SNI=www.bing.com LISTEN='::' sh install.sh
SNI="${SNI:-www.bing.com}"
PORT="${PORT:-443}"
LISTEN="${LISTEN:-::}"

EDGE_MAIN="https://dl-cdn.alpinelinux.org/alpine/edge/main"
EDGE_COMMUNITY="https://dl-cdn.alpinelinux.org/alpine/edge/community"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        red "请使用 root 用户运行此脚本。"
        exit 1
    fi
}

add_repo_if_missing() {
    repo="$1"
    if ! grep -qxF "$repo" "$REPO_FILE" 2>/dev/null; then
        echo "$repo" >> "$REPO_FILE"
        yellow "已添加仓库：$repo"
    else
        green "仓库已存在：$repo"
    fi
}

generate_uuid() {
    if [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        sing-box generate uuid
    fi
}

install_packages() {
    yellow "添加 Alpine edge/main 与 edge/community 仓库..."
    touch "$REPO_FILE"
    add_repo_if_missing "$EDGE_MAIN"
    add_repo_if_missing "$EDGE_COMMUNITY"

    yellow "更新 apk 索引..."
    apk update

    yellow "安装 sing-box、curl、openssl..."
    apk add --no-cache sing-box curl openssl

    if ! command -v rc-service >/dev/null 2>&1; then
        yellow "未检测到 OpenRC，正在安装 openrc..."
        apk add --no-cache openrc
    fi
}

generate_config() {
    UUID="$(generate_uuid)"
    SHORT_ID="$(openssl rand -hex 8)"

    yellow "生成 Reality 密钥..."
    KEYPAIR="$(sing-box generate reality-keypair)"
    PRIVATE_KEY="$(printf '%s\n' "$KEYPAIR" | awk -F: '/PrivateKey/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
    PUBLIC_KEY="$(printf '%s\n' "$KEYPAIR" | awk -F: '/PublicKey/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"

    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
        red "Reality 密钥生成失败："
        printf '%s\n' "$KEYPAIR"
        exit 1
    fi

    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ]; then
        BACKUP_FILE="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
        cp "$CONFIG_FILE" "$BACKUP_FILE"
        yellow "已备份旧配置：$BACKUP_FILE"
    fi

    cat > "$CONFIG_FILE" <<EOF_CONFIG
{
  "log": {
    "level": "error"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "$LISTEN",
      "listen_port": $PORT,
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$SNI",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": [
            "$SHORT_ID"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF_CONFIG

    yellow "检查 sing-box 配置..."
    sing-box check -c "$CONFIG_FILE"

    SERVER_IP="你的服务器IP"
    CLIENT_LINK="vless://$UUID@$SERVER_IP:$PORT?security=reality&encryption=none&flow=xtls-rprx-vision&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&sni=$SNI&type=tcp#VLESS-Reality-Vision"

    cat > "$INFO_FILE" <<EOF_INFO
=== VLESS Reality Vision 信息 ===

SNI: $SNI
PORT: $PORT
UUID: $UUID
Public Key: $PUBLIC_KEY
Short ID: $SHORT_ID

客户端链接：
$CLIENT_LINK

配置文件：$CONFIG_FILE
服务文件：$SERVICE_FILE
EOF_INFO
}

install_service() {
    SING_BOX_BIN="$(command -v sing-box)"

    cat > "$SERVICE_FILE" <<EOF_SERVICE
#!/sbin/openrc-run

name="sing-box"
description="sing-box service"
command="$SING_BOX_BIN"
command_args="run -c $CONFIG_FILE"
pidfile="/run/\${RC_SVCNAME}.pid"
command_background=true

output_log="/var/log/sing-box.log"
error_log="/var/log/sing-box.err"

depend() {
    need net localmount
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0755 /var/lib/sing-box
    checkpath --directory --owner root:root --mode 0755 /var/log
    $SING_BOX_BIN check -c $CONFIG_FILE >/dev/null 2>&1
}
EOF_SERVICE

    chmod +x "$SERVICE_FILE"
    rc-update add sing-box default >/dev/null 2>&1 || true
    rc-service sing-box restart
}

show_result() {
    green "=== 安装完成 ==="
    printf '\n'
    cat "$INFO_FILE"
    printf '\n'
    yellow "常用命令："
    cat <<'EOF_CMD'
rc-service sing-box restart       # 重启
rc-service sing-box status        # 查看状态
rc-service sing-box stop          # 停止
sing-box check -c /etc/sing-box/config.json  # 检查配置
cat /root/vless-reality-info.txt  # 查看客户端链接
ps -o pid,rss,comm -p $(pgrep sing-box)      # 查看内存占用
EOF_CMD
}

uninstall() {
    yellow "停止并移除 sing-box 服务..."
    rc-service sing-box stop >/dev/null 2>&1 || true
    rc-update del sing-box default >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE"

    yellow "移除配置与连接信息..."
    rm -rf "$CONFIG_DIR" "$INFO_FILE" /var/lib/sing-box /var/log/sing-box.log /var/log/sing-box.err

    yellow "卸载 sing-box 包..."
    apk del sing-box >/dev/null 2>&1 || true

    green "卸载完成。edge 仓库不会自动删除，如需删除请手动编辑：$REPO_FILE"
}

main() {
    need_root

    case "${1:-install}" in
        install)
            printf '=== Alpine 极低内存 VLESS-Reality-Vision 安装脚本 ===\n'
            printf 'SNI: %s\n' "$SNI"
            printf 'PORT: %s\n' "$PORT"
            printf 'LISTEN: %s\n\n' "$LISTEN"
            install_packages
            generate_config
            install_service
            show_result
            ;;
        uninstall)
            uninstall
            ;;
        *)
            red "用法：sh install.sh [install|uninstall]"
            exit 1
            ;;
    esac
}

main "$@"
