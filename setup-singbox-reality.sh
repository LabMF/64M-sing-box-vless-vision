#!/bin/ash
# setup-singbox-reality.sh
# Alpine low-memory sing-box VLESS + REALITY installer/config updater.
# Designed for tiny Alpine VPS/container: upload the musl sing-box binary first,
# then run this script. It does NOT download or decompress sing-box on the server.

set -eu

BIN_SRC="${BIN_SRC:-/root/sing-box}"
BIN_DST="/usr/local/bin/sing-box"
CONF_DIR="/usr/local/etc/sing-box"
CONF_FILE="${CONF_DIR}/config.json"
LOG_DIR="/var/log/sing-box"
INFO_FILE="/root/singbox-vless-reality-info.txt"

DEFAULT_PORT="${DEFAULT_PORT:-443}"
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-www.cloudflare.com}"

log() {
  echo "[+] $*"
}

warn() {
  echo "[!] $*" >&2
}

die() {
  echo "[x] $*" >&2
  exit 1
}

pause() {
  echo
  printf "按回车键继续..."
  read -r _ || true
}

require_root() {
  [ "$(id -u)" = "0" ] || die "请使用 root 用户运行。"
}

protect_ssh() {
  # In very low-memory environments, reduce the chance that sshd or this shell
  # gets killed first by the OOM killer.
  echo -1000 > /proc/$$/oom_score_adj 2>/dev/null || true
  for p in $(pgrep -x sshd 2>/dev/null || true); do
    echo -1000 > /proc/$p/oom_score_adj 2>/dev/null || true
  done
}

ensure_openrc_runtime() {
  mkdir -p /run/openrc
  touch /run/openrc/softlevel 2>/dev/null || true
}

validate_port() {
  port="$1"

  case "$port" in
    *[!0-9]*|"")
      die "端口必须是数字。"
      ;;
  esac

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    die "端口范围必须是 1-65535。"
  fi
}

validate_domain() {
  domain="$1"

  case "$domain" in
    ""|*"/"*|*":"*|*" "*)
      die "域名格式不正确，请输入类似 www.cloudflare.com 的域名，不要带 https:// 或端口。"
      ;;
  esac
}

ask_port_domain() {
  echo
  printf "请输入监听端口 [%s]: " "$DEFAULT_PORT"
  read -r PORT_INPUT || true
  PORT="${PORT_INPUT:-$DEFAULT_PORT}"
  validate_port "$PORT"

  printf "请输入 REALITY 域名 / SNI [%s]: " "$DEFAULT_DOMAIN"
  read -r DOMAIN_INPUT || true
  REALITY_DOMAIN="${DOMAIN_INPUT:-$DEFAULT_DOMAIN}"
  validate_domain "$REALITY_DOMAIN"

  HANDSHAKE_SERVER="$REALITY_DOMAIN"
  HANDSHAKE_PORT="443"
}

install_binary() {
  [ -f "$BIN_SRC" ] || die "没有找到 ${BIN_SRC}。请先把 sing-box musl 二进制上传到 ${BIN_SRC}。"

  mkdir -p /usr/local/bin "$CONF_DIR" "$LOG_DIR"

  log "安装 sing-box 二进制：${BIN_SRC} -> ${BIN_DST}"
  cp "$BIN_SRC" "$BIN_DST"
  chmod 755 "$BIN_DST"

  log "sing-box 版本信息："
  "$BIN_DST" version
}

check_binary_exists() {
  [ -x "$BIN_DST" ] || die "没有找到 ${BIN_DST}。请先选择安装，或手动安装 sing-box 二进制。"
}

stop_conflicting_services() {
  log "停止可能占用端口的旧服务..."

  rc-service xray stop 2>/dev/null || true
  rc-update del xray default 2>/dev/null || true
  pkill -f 'xray run' 2>/dev/null || true

  rc-service sing-box stop 2>/dev/null || true
  pkill -f 'sing-box run' 2>/dev/null || true
}

generate_reality_values() {
  UUID="$(cat /proc/sys/kernel/random/uuid)"
  KEYPAIR="$("$BIN_DST" generate reality-keypair)"

  PRIVATE_KEY="$(echo "$KEYPAIR" | awk -F': *' 'tolower($1) ~ /private/ {print $2; exit}')"
  PUBLIC_KEY="$(echo "$KEYPAIR" | awk -F': *' 'tolower($1) ~ /public/ {print $2; exit}')"
  SHORT_ID="$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"

  [ -n "$UUID" ] || die "UUID 生成失败。"
  [ -n "$PRIVATE_KEY" ] || die "REALITY private_key 生成失败。"
  [ -n "$PUBLIC_KEY" ] || die "REALITY public_key 生成失败。"
  [ -n "$SHORT_ID" ] || die "REALITY short_id 生成失败。"
}

write_config() {
  mkdir -p "$CONF_DIR" "$LOG_DIR"

  cat > "$CONF_FILE" <<EOF
{
  "log": {
    "level": "warn",
    "output": "${LOG_DIR}/sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality-in",
      "listen": "0.0.0.0",
      "listen_port": ${PORT},
      "users": [
        {
          "uuid": "${UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${REALITY_DOMAIN}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${HANDSHAKE_SERVER}",
            "server_port": ${HANDSHAKE_PORT}
          },
          "private_key": "${PRIVATE_KEY}",
          "short_id": [
            "${SHORT_ID}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

  chmod 600 "$CONF_FILE"
}

write_openrc_service() {
  cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run

name="sing-box"
description="sing-box VLESS REALITY"

command="${BIN_DST}"
command_args="run -c ${CONF_FILE}"
command_background="yes"
pidfile="/run/sing-box.pid"

output_log="/dev/null"
error_log="${LOG_DIR}/error.log"

# Low-memory Go runtime hints. These are helpful on tiny machines,
# but cannot guarantee stability if RAM is extremely limited.
export GOMEMLIMIT="32MiB"
export GOGC="25"

depend() {
  need net
}

start_pre() {
  mkdir -p "${LOG_DIR}"
  touch "${LOG_DIR}/sing-box.log"
  touch "${LOG_DIR}/error.log"
}
EOF

  chmod +x /etc/init.d/sing-box
  ensure_openrc_runtime
  rc-update add sing-box default >/dev/null 2>&1 || true
}

test_and_restart() {
  log "检查 sing-box 配置..."
  "$BIN_DST" check -c "$CONF_FILE"

  log "启动 / 重启 sing-box..."
  rc-service sing-box restart

  log "服务状态："
  rc-service sing-box status || true
}

detect_server_ip() {
  SERVER_ADDR="${SERVER_ADDR:-}"

  if [ -z "$SERVER_ADDR" ]; then
    SERVER_ADDR="$(wget -qO- https://api.ipify.org 2>/dev/null || true)"
  fi

  if [ -z "$SERVER_ADDR" ]; then
    SERVER_ADDR="你的服务器IP"
    warn "未能自动获取公网 IP，请在客户端链接中手动替换服务器地址。"
  fi
}

write_info() {
  detect_server_ip

  LINK="vless://${UUID}@${SERVER_ADDR}:${PORT}?encryption=none&security=reality&sni=${REALITY_DOMAIN}&fp=chrome&type=tcp&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#singbox-reality"

  cat > "$INFO_FILE" <<EOF
sing-box VLESS + REALITY

Address: ${SERVER_ADDR}
Port: ${PORT}
UUID: ${UUID}
Flow: xtls-rprx-vision
Network: tcp
Security: reality
SNI / serverName: ${REALITY_DOMAIN}
Handshake: ${HANDSHAKE_SERVER}:${HANDSHAKE_PORT}
PublicKey / pbk: ${PUBLIC_KEY}
ShortId / sid: ${SHORT_ID}
Fingerprint: chrome

Client link:
${LINK}

Config:
${CONF_FILE}

Service:
rc-service sing-box status
rc-service sing-box restart
rc-service sing-box stop

Logs:
${LOG_DIR}/sing-box.log
${LOG_DIR}/error.log
EOF

  chmod 600 "$INFO_FILE"

  echo
  echo "==================== 完成 ===================="
  cat "$INFO_FILE"
  echo "=============================================="
  echo
  echo "提示：请确认云服务器安全组 / 防火墙已放行 TCP ${PORT}。"
}

install_mode() {
  echo
  echo "=== 安装 sing-box + 生成配置 ==="
  ask_port_domain

  protect_ssh
  install_binary
  stop_conflicting_services
  generate_reality_values
  write_config
  write_openrc_service
  test_and_restart
  write_info
}

update_config_mode() {
  echo
  echo "=== 更新配置 ==="
  ask_port_domain

  protect_ssh
  check_binary_exists
  generate_reality_values
  write_config
  write_openrc_service
  test_and_restart
  write_info
}

show_status() {
  echo
  echo "=== 当前状态 ==="
  if [ -x "$BIN_DST" ]; then
    "$BIN_DST" version || true
  else
    warn "未安装 sing-box：${BIN_DST} 不存在。"
  fi

  echo
  rc-service sing-box status 2>/dev/null || true

  echo
  ss -lntp 2>/dev/null | grep sing-box || true

  echo
  if [ -f "$INFO_FILE" ]; then
    cat "$INFO_FILE"
  else
    warn "未找到节点信息文件：${INFO_FILE}"
  fi

  pause
}

main_menu() {
  while true; do
    clear 2>/dev/null || true
    echo "=============================================="
    echo " sing-box VLESS + REALITY for Alpine"
    echo "=============================================="
    echo " 1) 安装"
    echo " 2) 更新配置"
    echo " 3) 查看状态"
    echo " 0) 退出"
    echo "=============================================="
    printf "请选择: "
    read -r choice || true

    case "$choice" in
      1)
        install_mode
        break
        ;;
      2)
        update_config_mode
        break
        ;;
      3)
        show_status
        ;;
      0)
        exit 0
        ;;
      *)
        echo "无效选择。"
        pause
        ;;
    esac
  done
}

main() {
  require_root
  main_menu
}

main "$@"
