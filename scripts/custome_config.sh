#!/bin/bash
set -e

echo "=================================================="
echo " NanoPi R5C FriendlyWrt 25.12 Lite Configuration"
echo "=================================================="

CONFIG_FILE="configs/rockchip/01-nanopi"
FWRT_DIR="friendlywrt"
PACKAGE_DIR="${FWRT_DIR}/package"

# --------------------------------------------------
# 基础检查
# --------------------------------------------------

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "ERROR: 找不到配置文件：${CONFIG_FILE}"
    exit 1
fi

if [ ! -d "${PACKAGE_DIR}" ]; then
    echo "ERROR: 找不到软件包目录：${PACKAGE_DIR}"
    exit 1
fi

# --------------------------------------------------
# 不生成 SDK、ImageBuilder、Toolchain
# 减少 Actions 时间和磁盘占用
# --------------------------------------------------

echo ">>> Disable SDK, ImageBuilder and Toolchain"

sed -i \
    -e '/^CONFIG_MAKE_TOOLCHAIN=y$/d' \
    -e 's/^CONFIG_IB=y$/# CONFIG_IB is not set/' \
    -e 's/^CONFIG_SDK=y$/# CONFIG_SDK is not set/' \
    "${CONFIG_FILE}"

# --------------------------------------------------
# Git 克隆重试函数
# --------------------------------------------------

clone_repo() {
    local repo_url="$1"
    local target_dir="$2"

    for retry in 1 2 3; do
        echo ">>> Clone ${repo_url}, attempt ${retry}/3"

        rm -rf "${target_dir}"

        if git \
            -c http.version=HTTP/1.1 \
            clone \
            --depth=1 \
            --single-branch \
            "${repo_url}" \
            "${target_dir}"; then

            echo ">>> Clone succeeded: ${target_dir}"
            return 0
        fi

        echo "WARNING: Clone failed, retry after 15 seconds"
        sleep 15
    done

    echo "ERROR: Failed to clone ${repo_url}"
    return 1
}

# --------------------------------------------------
# 清除可能冲突的旧 Passwall
# --------------------------------------------------

echo ">>> Clean old Passwall packages"

rm -rf "${PACKAGE_DIR}/passwall"
rm -rf "${PACKAGE_DIR}/passwall-luci"
rm -rf "${PACKAGE_DIR}/passwall-packages"

# 如果 feeds 中已有旧版 Passwall，也进行删除
rm -rf "${FWRT_DIR}/feeds/luci/applications/luci-app-passwall"
rm -rf "${FWRT_DIR}/feeds/packages/net/xray-core"
rm -rf "${FWRT_DIR}/feeds/packages/net/shadowsocksr-libev"

# --------------------------------------------------
# 添加 Passwall
# --------------------------------------------------

echo ">>> Add Passwall"

clone_repo \
    "https://github.com/Openwrt-Passwall/openwrt-passwall.git" \
    "${PACKAGE_DIR}/passwall-luci"

clone_repo \
    "https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git" \
    "${PACKAGE_DIR}/passwall-packages"

# --------------------------------------------------
# 精简 Passwall 依赖包源码
# 仅保留 Xray 所需的基本组件
# --------------------------------------------------

echo ">>> Remove unused Passwall components"

rm -rf "${PACKAGE_DIR}/passwall-packages/shadowsocksr-libev"
rm -rf "${PACKAGE_DIR}/passwall-packages/sing-box"
rm -rf "${PACKAGE_DIR}/passwall-packages/geoview"
rm -rf "${PACKAGE_DIR}/passwall-packages/hysteria"
rm -rf "${PACKAGE_DIR}/passwall-packages/naiveproxy"
rm -rf "${PACKAGE_DIR}/passwall-packages/shadowsocks-rust"
rm -rf "${PACKAGE_DIR}/passwall-packages/shadow-tls"
rm -rf "${PACKAGE_DIR}/passwall-packages/tuic-client"
rm -rf "${PACKAGE_DIR}/passwall-packages/v2ray-plugin"
rm -rf "${PACKAGE_DIR}/passwall-packages/xray-plugin"
rm -rf "${PACKAGE_DIR}/passwall-packages/simple-obfs"

# --------------------------------------------------
# 修改 Passwall 默认选项
# 防止 defconfig 自动重新启用 SSR、Sing-box 等组件
# --------------------------------------------------

PASSWALL_MAKEFILE="${PACKAGE_DIR}/passwall-luci/luci-app-passwall/Makefile"

if [ -f "${PASSWALL_MAKEFILE}" ]; then
    echo ">>> Patch Passwall default selections"

    python3 - "${PASSWALL_MAKEFILE}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

disable_options = [
    "ShadowsocksR_Libev_Client",
    "ShadowsocksR_Libev_Server",
    "SingBox",
    "Geoview",
    "Shadowsocks_Rust_Client",
    "Shadowsocks_Rust_Server",
    "Hysteria",
    "NaiveProxy",
    "Shadow_TLS",
    "Simple_Obfs",
    "V2ray_Plugin",
    "Xray_Plugin",
    "Haproxy",
]

for option in disable_options:
    pattern = (
        rf"(config PACKAGE_\$\(PKG_NAME\)_INCLUDE_{re.escape(option)}"
        rf".*?)(\n\s*default\s+)y"
    )

    text = re.sub(
        pattern,
        r"\1\2n",
        text,
        count=1,
        flags=re.S,
    )

path.write_text(text, encoding="utf-8")
print("Passwall defaults patched.")
PY
else
    echo "WARNING: 找不到 Passwall Makefile：${PASSWALL_MAKEFILE}"
fi

# --------------------------------------------------
# 清理之前追加的配置
# --------------------------------------------------

echo ">>> Clean previous R5C custom configuration"

sed -i \
    '/# BEGIN R5C LITE PACKAGES/,/# END R5C LITE PACKAGES/d' \
    "${CONFIG_FILE}"

# 删除旧脚本可能写入的相关配置，避免 y 与 not set 同时存在
sed -i \
    -e '/CONFIG_PACKAGE_luci-app-passwall/d' \
    -e '/CONFIG_PACKAGE_luci-i18n-passwall/d' \
    -e '/CONFIG_PACKAGE_shadowsocksr-libev/d' \
    -e '/CONFIG_PACKAGE_sing-box/d' \
    -e '/CONFIG_PACKAGE_geoview/d' \
    -e '/CONFIG_PACKAGE_ntopng/d' \
    -e '/CONFIG_PACKAGE_collectd/d' \
    -e '/CONFIG_PACKAGE_luci-app-statistics/d' \
    -e '/CONFIG_PACKAGE_adguardhome/d' \
    -e '/CONFIG_PACKAGE_smartdns/d' \
    -e '/CONFIG_PACKAGE_luci-app-smartdns/d' \
    -e '/CONFIG_PACKAGE_crowdsec/d' \
    -e '/CONFIG_PACKAGE_docker-compose/d' \
    -e '/CONFIG_PACKAGE_dockerd/d' \
    -e '/CONFIG_PACKAGE_luci-app-dockerman/d' \
    -e '/CONFIG_PACKAGE_luci-i18n-dockerman/d' \
    -e '/CONFIG_PACKAGE_zerotier/d' \
    -e '/CONFIG_PACKAGE_wireguard-tools/d' \
    -e '/CONFIG_PACKAGE_luci-proto-wireguard/d' \
    -e '/CONFIG_PACKAGE_nlbwmon/d' \
    -e '/CONFIG_PACKAGE_luci-app-nlbwmon/d' \
    -e '/CONFIG_PACKAGE_banip/d' \
    -e '/CONFIG_PACKAGE_luci-app-banip/d' \
    -e '/CONFIG_PACKAGE_luci-app-ttyd/d' \
    -e '/CONFIG_PACKAGE_luci-app-wol/d' \
    -e '/CONFIG_PACKAGE_luci-app-watchcat/d' \
    -e '/CONFIG_PACKAGE_luci-app-sqm/d' \
    "${CONFIG_FILE}"

# --------------------------------------------------
# 添加精简软件包
# --------------------------------------------------

echo ">>> Add lite package configuration"

cat >> "${CONFIG_FILE}" <<'EOF'

# BEGIN R5C LITE PACKAGES

# ==================================================
# NanoPi R5C FriendlyWrt 25.12 Lite Build
# ==================================================

# --------------------------------------------------
# Docker
# --------------------------------------------------

CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker-compose=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y

# --------------------------------------------------
# Passwall
# 只保留 Xray
# --------------------------------------------------

CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y

CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y
# CONFIG_PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy is not set

CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y

# 关闭其他代理组件
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_NaiveProxy is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadow_TLS is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray_Plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy is not set

# SSR 软件包明确关闭
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-check is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-local is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-nat is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-server is not set

# --------------------------------------------------
# VPN / 虚拟组网
# --------------------------------------------------

CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_luci-i18n-wireguard-zh-cn=y

# --------------------------------------------------
# 轻量流量统计
# --------------------------------------------------

CONFIG_PACKAGE_nlbwmon=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_luci-i18n-nlbwmon-zh-cn=y

# 不编译重量级 ntopng 和 collectd
# CONFIG_PACKAGE_ntopng is not set
# CONFIG_PACKAGE_luci-app-statistics is not set

# --------------------------------------------------
# 安全
# --------------------------------------------------

CONFIG_PACKAGE_banip=y
CONFIG_PACKAGE_luci-app-banip=y
CONFIG_PACKAGE_luci-i18n-banip-zh-cn=y

# CrowdSec 后续通过 Docker 部署
# CONFIG_PACKAGE_crowdsec is not set
# CONFIG_PACKAGE_crowdsec-firewall-bouncer is not set
# CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer is not set

# --------------------------------------------------
# LuCI 运维工具
# --------------------------------------------------

CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y

CONFIG_PACKAGE_etherwake=y
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_luci-i18n-wol-zh-cn=y

CONFIG_PACKAGE_watchcat=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_luci-i18n-watchcat-zh-cn=y

# --------------------------------------------------
# SQM
# --------------------------------------------------

CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_luci-i18n-sqm-zh-cn=y

# --------------------------------------------------
# 常用命令行工具
# --------------------------------------------------

CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_btop=y

CONFIG_PACKAGE_iftop=y
CONFIG_PACKAGE_iptraf-ng=y
CONFIG_PACKAGE_tcpdump=y

CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y

CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_vim-fuller=y

CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_tree=y
CONFIG_PACKAGE_tmux=y

# --------------------------------------------------
# Docker 存储支持
# --------------------------------------------------

CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_resize2fs=y
CONFIG_PACKAGE_kmod-fs-ext4=y

# --------------------------------------------------
# 明确不编译的大型组件
# --------------------------------------------------

# CONFIG_PACKAGE_ntopng is not set
# CONFIG_PACKAGE_collectd is not set
# CONFIG_PACKAGE_luci-app-statistics is not set
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_smartdns is not set
# CONFIG_PACKAGE_luci-app-smartdns is not set

# END R5C LITE PACKAGES
EOF

# --------------------------------------------------
# 首次启动配置
# --------------------------------------------------

echo ">>> Create first-boot configuration"

mkdir -p "${FWRT_DIR}/files/etc/uci-defaults"

cat > "${FWRT_DIR}/files/etc/uci-defaults/99-r5c-custom" <<'EOF'
#!/bin/sh

# LAN 地址
uci set network.lan.ipaddr='192.168.166.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# 开启 LAN 侧 SSH 密码登录
if uci -q get dropbear.@dropbear[0] >/dev/null 2>&1; then
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    uci set dropbear.@dropbear[0].Interface='lan'
    uci commit dropbear
fi

# 不修改 root 密码，保留 FriendlyWrt 默认密码

exit 0
EOF

chmod +x "${FWRT_DIR}/files/etc/uci-defaults/99-r5c-custom"

# --------------------------------------------------
# 最后再次强制关闭大包和 SSR
# --------------------------------------------------

echo ">>> Enforce unwanted packages disabled"

sed -i \
    -e '/^CONFIG_PACKAGE_ntopng=y$/d' \
    -e '/^CONFIG_PACKAGE_collectd.*=y$/d' \
    -e '/^CONFIG_PACKAGE_luci-app-statistics=y$/d' \
    -e '/^CONFIG_PACKAGE_adguardhome=y$/d' \
    -e '/^CONFIG_PACKAGE_smartdns=y$/d' \
    -e '/^CONFIG_PACKAGE_luci-app-smartdns=y$/d' \
    -e '/^CONFIG_PACKAGE_shadowsocksr-libev.*=y$/d' \
    -e '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=y$/d' \
    -e '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview=y$/d' \
    -e '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev.*=y$/d' \
    "${CONFIG_FILE}"

cat >> "${CONFIG_FILE}" <<'EOF'

# Final forced disables
# CONFIG_PACKAGE_ntopng is not set
# CONFIG_PACKAGE_collectd is not set
# CONFIG_PACKAGE_luci-app-statistics is not set
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_smartdns is not set
# CONFIG_PACKAGE_luci-app-smartdns is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-check is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-local is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-nat is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-server is not set
EOF

echo "=================================================="
echo " R5C Lite configuration completed"
echo "=================================================="
echo " LAN IP       : 192.168.166.1"
echo " Root password: FriendlyWrt default"
echo " Docker       : enabled"
echo " Passwall     : enabled, Xray only"
echo " ZeroTier     : enabled"
echo " WireGuard    : enabled"
echo " nlbwmon      : enabled"
echo " ntopng       : disabled"
echo " AdGuard Home : disabled"
echo " SmartDNS     : disabled"
echo " CrowdSec     : disabled"
echo "=================================================="
