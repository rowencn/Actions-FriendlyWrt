#!/bin/bash
set -e

echo "=================================================="
echo " NanoPi R5C FriendlyWrt 25.12 custom configuration"
echo "=================================================="

CONFIG_FILE="configs/rockchip/01-nanopi"
FWRT_DIR="friendlywrt"
PACKAGE_DIR="${FWRT_DIR}/package"

# --------------------------------------------------
# Basic checks
# --------------------------------------------------

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "ERROR: configuration file not found:"
    echo "       ${CONFIG_FILE}"
    exit 1
fi

if [ ! -d "${PACKAGE_DIR}" ]; then
    echo "ERROR: FriendlyWrt package directory not found:"
    echo "       ${PACKAGE_DIR}"
    exit 1
fi

# --------------------------------------------------
# Disable SDK / ImageBuilder / Toolchain
# --------------------------------------------------

echo ">>> Disable SDK, ImageBuilder and Toolchain output"

sed -i \
    -e '/^CONFIG_MAKE_TOOLCHAIN=y$/d' \
    -e 's/^CONFIG_IB=y$/# CONFIG_IB is not set/' \
    -e 's/^CONFIG_SDK=y$/# CONFIG_SDK is not set/' \
    "${CONFIG_FILE}"

# --------------------------------------------------
# Git clone helper
# --------------------------------------------------

clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local retry

    for retry in 1 2 3; do
        echo ">>> Clone attempt ${retry}/3"
        echo "    ${repo_url}"

        rm -rf "${target_dir}"

        if git \
            -c http.version=HTTP/1.1 \
            clone \
            --depth=1 \
            --single-branch \
            "${repo_url}" \
            "${target_dir}"; then

            echo ">>> Clone succeeded:"
            echo "    ${target_dir}"
            return 0
        fi

        echo "WARNING: clone failed, retry after 15 seconds..."
        sleep 15
    done

    echo "ERROR: failed to clone repository:"
    echo "       ${repo_url}"
    return 1
}

# --------------------------------------------------
# Add Passwall
# --------------------------------------------------

echo ">>> Download Passwall sources"

clone_repo \
    "https://github.com/Openwrt-Passwall/openwrt-passwall.git" \
    "${PACKAGE_DIR}/passwall"

clone_repo \
    "https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git" \
    "${PACKAGE_DIR}/passwall-packages"

# --------------------------------------------------
# Disable shadowsocksr-libev
# --------------------------------------------------

echo ">>> Disable Passwall shadowsocksr-libev"

PASSWALL_MAKEFILE="${PACKAGE_DIR}/passwall/luci-app-passwall/Makefile"

if [ -f "${PASSWALL_MAKEFILE}" ]; then
    python3 - "${PASSWALL_MAKEFILE}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

patterns = [
    (
        r'(config PACKAGE_\$\(PKG_NAME\)_INCLUDE_ShadowsocksR_Libev_Client'
        r'.*?)(\n\s*default\s+)y',
        r'\1\2n'
    ),
    (
        r'(config PACKAGE_\$\(PKG_NAME\)_INCLUDE_ShadowsocksR_Libev_Server'
        r'.*?)(\n\s*default\s+)y',
        r'\1\2n'
    ),
]

changed = 0

for pattern, replacement in patterns:
    text, count = re.subn(
        pattern,
        replacement,
        text,
        count=1,
        flags=re.S
    )
    changed += count

path.write_text(text, encoding="utf-8")
print(f"Passwall Makefile patched, changed options: {changed}")
PY
else
    echo "WARNING: Passwall Makefile not found:"
    echo "         ${PASSWALL_MAKEFILE}"
fi

# 彻底移除导致下载失败的软件包
rm -rf "${PACKAGE_DIR}/passwall-packages/shadowsocksr-libev"

# --------------------------------------------------
# Remove old custom configuration
# --------------------------------------------------

echo ">>> Clean previous custom configuration"

sed -i \
    '/# BEGIN R5C CUSTOM PACKAGES/,/# END R5C CUSTOM PACKAGES/d' \
    "${CONFIG_FILE}"

# 删除可能已经存在的重复配置
sed -i \
    -e '/CONFIG_PACKAGE_luci-app-passwall/d' \
    -e '/CONFIG_PACKAGE_luci-i18n-passwall/d' \
    -e '/CONFIG_PACKAGE_shadowsocksr-libev/d' \
    -e '/CONFIG_PACKAGE_docker-compose/d' \
    -e '/CONFIG_PACKAGE_dockerd/d' \
    -e '/CONFIG_PACKAGE_luci-app-dockerman/d' \
    -e '/CONFIG_PACKAGE_luci-i18n-dockerman/d' \
    -e '/CONFIG_PACKAGE_ntopng/d' \
    -e '/CONFIG_PACKAGE_nlbwmon/d' \
    -e '/CONFIG_PACKAGE_luci-app-nlbwmon/d' \
    -e '/CONFIG_PACKAGE_luci-app-statistics/d' \
    -e '/CONFIG_PACKAGE_adguardhome/d' \
    -e '/CONFIG_PACKAGE_smartdns/d' \
    -e '/CONFIG_PACKAGE_luci-app-smartdns/d' \
    -e '/CONFIG_PACKAGE_zerotier/d' \
    -e '/CONFIG_PACKAGE_wireguard-tools/d' \
    -e '/CONFIG_PACKAGE_luci-proto-wireguard/d' \
    -e '/CONFIG_PACKAGE_banip/d' \
    -e '/CONFIG_PACKAGE_luci-app-banip/d' \
    -e '/CONFIG_PACKAGE_luci-app-ttyd/d' \
    -e '/CONFIG_PACKAGE_luci-app-wol/d' \
    -e '/CONFIG_PACKAGE_luci-app-watchcat/d' \
    -e '/CONFIG_PACKAGE_luci-app-sqm/d' \
    "${CONFIG_FILE}"

# --------------------------------------------------
# Add packages
# --------------------------------------------------

echo ">>> Add R5C packages"

cat >> "${CONFIG_FILE}" <<'EOF'

# BEGIN R5C CUSTOM PACKAGES

# ==================================================
# NanoPi R5C company build
# FriendlyWrt 25.12 / Docker edition
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
# Network monitoring
# --------------------------------------------------

CONFIG_PACKAGE_nlbwmon=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_luci-i18n-nlbwmon-zh-cn=y

CONFIG_PACKAGE_ntopng=y

CONFIG_PACKAGE_collectd=y
CONFIG_PACKAGE_collectd-mod-cpu=y
CONFIG_PACKAGE_collectd-mod-df=y
CONFIG_PACKAGE_collectd-mod-disk=y
CONFIG_PACKAGE_collectd-mod-interface=y
CONFIG_PACKAGE_collectd-mod-iwinfo=y
CONFIG_PACKAGE_collectd-mod-load=y
CONFIG_PACKAGE_collectd-mod-memory=y
CONFIG_PACKAGE_collectd-mod-network=y
CONFIG_PACKAGE_collectd-mod-rrdtool=y
CONFIG_PACKAGE_collectd-mod-thermal=y

CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_luci-i18n-statistics-zh-cn=y

# --------------------------------------------------
# DNS
# --------------------------------------------------

CONFIG_PACKAGE_adguardhome=y

CONFIG_PACKAGE_smartdns=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y

# --------------------------------------------------
# VPN / virtual network
# --------------------------------------------------

CONFIG_PACKAGE_zerotier=y

CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_luci-i18n-wireguard-zh-cn=y

# --------------------------------------------------
# Security
# --------------------------------------------------

CONFIG_PACKAGE_banip=y
CONFIG_PACKAGE_luci-app-banip=y
CONFIG_PACKAGE_luci-i18n-banip-zh-cn=y

# CrowdSec 暂不直接编译
# 建议后续通过 Docker Compose 部署
# CONFIG_PACKAGE_crowdsec is not set
# CONFIG_PACKAGE_crowdsec-firewall-bouncer is not set
# CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer is not set

# --------------------------------------------------
# Passwall
# --------------------------------------------------

CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y

# FriendlyWrt 25.12 使用 firewall4 / nftables
CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y
# CONFIG_PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy is not set

# 常用内核
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=y

# 常用插件
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin=y

# 禁止 ShadowsocksR Libev
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set

# 禁止不需要的大型组件
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_NaiveProxy is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadow_TLS is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray_Plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy is not set

# SSR 二进制包强制关闭
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-check is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-local is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-nat is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-server is not set

# --------------------------------------------------
# LuCI operations
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
# Command-line tools
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

CONFIG_PACKAGE_git=y
CONFIG_PACKAGE_git-http=y

CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_mc=y
CONFIG_PACKAGE_tree=y
CONFIG_PACKAGE_tmux=y
CONFIG_PACKAGE_screen=y

# --------------------------------------------------
# Storage and Docker filesystem support
# --------------------------------------------------

CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_lsblk=y

CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_resize2fs=y
CONFIG_PACKAGE_kmod-fs-ext4=y

# END R5C CUSTOM PACKAGES
EOF

# --------------------------------------------------
# First-boot defaults
# --------------------------------------------------

echo ">>> Create first-boot defaults"

mkdir -p "${FWRT_DIR}/files/etc/uci-defaults"

cat > "${FWRT_DIR}/files/etc/uci-defaults/99-r5c-custom" <<'EOF'
#!/bin/sh

# --------------------------------------------------
# LAN address
# --------------------------------------------------

uci set network.lan.ipaddr='192.168.166.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# --------------------------------------------------
# SSH
# --------------------------------------------------

if uci -q get dropbear.@dropbear[0] >/dev/null 2>&1; then
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    uci set dropbear.@dropbear[0].Interface='lan'
    uci commit dropbear
fi

# 不修改 root 密码
# 保留 FriendlyWrt 官方默认密码

exit 0
EOF

chmod +x "${FWRT_DIR}/files/etc/uci-defaults/99-r5c-custom"

# --------------------------------------------------
# Final forced disable for SSR Libev
# --------------------------------------------------

echo ">>> Enforce shadowsocksr-libev disabled"

sed -i \
    -e '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client=y$/d' \
    -e '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server=y$/d' \
    -e '/^CONFIG_PACKAGE_shadowsocksr-libev.*=y$/d' \
    "${CONFIG_FILE}"

cat >> "${CONFIG_FILE}" <<'EOF'

# Final forced disable for ShadowsocksR Libev
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-check is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-local is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-nat is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir is not set
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-server is not set
EOF

# --------------------------------------------------
# Summary
# --------------------------------------------------

echo "=================================================="
echo " R5C custom configuration completed"
echo "=================================================="
echo " LAN address       : 192.168.166.1"
echo " SSH password login: enabled on LAN"
echo " Root password     : FriendlyWrt default"
echo " Passwall          : enabled"
echo " SSR Libev         : disabled"
echo " CrowdSec          : not included"
echo "=================================================="
