#!/bin/bash
set -e

echo "=================================================="
echo " NanoPi R5C FriendlyWrt 25.12 custom configuration"
echo "=================================================="

# Actions-FriendlyWrt 官方基础配置文件
CONFIG_FILE="configs/rockchip/01-nanopi"

# FriendlyWrt 源码目录
FWRT_DIR="friendlywrt"
PACKAGE_DIR="${FWRT_DIR}/package"

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

echo ">>> Disable SDK, ImageBuilder and toolchain output"

# 不额外生成 SDK、ImageBuilder、Toolchain
# 可以显著减少 Actions 磁盘占用和编译时间
sed -i \
    -e '/^CONFIG_MAKE_TOOLCHAIN=y$/d' \
    -e 's/^CONFIG_IB=y$/# CONFIG_IB is not set/' \
    -e 's/^CONFIG_SDK=y$/# CONFIG_SDK is not set/' \
    "${CONFIG_FILE}"

# --------------------------------------------------
# Passwall
# --------------------------------------------------

clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local retry

    for retry in 1 2 3; do
        echo ">>> Clone attempt ${retry}/3: ${repo_url}"

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

        echo "WARNING: clone failed, waiting before retry..."
        sleep 15
    done

    echo "ERROR: failed to clone repository:"
    echo "       ${repo_url}"
    return 1
}

echo ">>> Download Passwall sources"

clone_repo \
    "https://github.com/Openwrt-Passwall/openwrt-passwall.git" \
    "${PACKAGE_DIR}/passwall"

clone_repo \
    "https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git" \
    "${PACKAGE_DIR}/passwall-packages"

# --------------------------------------------------
# Disable ShadowsocksR Libev
# --------------------------------------------------

PASSWALL_MAKEFILE="${PACKAGE_DIR}/passwall/luci-app-passwall/Makefile"

if [ -f "${PASSWALL_MAKEFILE}" ]; then
    echo ">>> Disable Passwall ShadowsocksR Libev defaults"

    # Passwall 当前默认把 SSR Libev Client 设为 y。
    # 将该选项对应的默认值改成 n，防止 make defconfig 自动重新选中。
    python3 - "${PASSWALL_MAKEFILE}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

pattern = (
    r'(config PACKAGE_\$\(PKG_NAME\)_INCLUDE_ShadowsocksR_Libev_Client'
    r'.*?)(\n\s*default\s+)y'
)

new_text, count = re.subn(
    pattern,
    r'\1\2n',
    text,
    count=1,
    flags=re.S,
)

if count == 0:
    print("WARNING: SSR Libev Client default option was not patched.")
else:
    path.write_text(new_text, encoding="utf-8")
    print("SSR Libev Client default changed from y to n.")
PY
else
    echo "WARNING: Passwall Makefile not found:"
    echo "         ${PASSWALL_MAKEFILE}"
fi

# 完全移除当前下载失败的软件包。
# 在配置已关闭的情况下，Passwall 不需要这个目录。
rm -rf "${PACKAGE_DIR}/passwall-packages/shadowsocksr-libev"

# --------------------------------------------------
# Clean previous custom package block
# --------------------------------------------------

echo ">>> Update FriendlyWrt package configuration"

sed -i \
    '/# BEGIN R5C CUSTOM PACKAGES/,/# END R5C CUSTOM PACKAGES/d' \
    "${CONFIG_FILE}"

# 删除旧配置，防止同一个选项既存在 y 又存在 not set
sed -i \
    -e '/CONFIG_PACKAGE_luci-app-passwall/d' \
    -e '/CONFIG_PACKAGE_shadowsocksr-libev/d' \
    -e '/CONFIG_PACKAGE_docker-compose/d' \
    -e '/CONFIG_PACKAGE_dockerd/d' \
    -e '/CONFIG_PACKAGE_luci-app-dockerman/d' \
    -e '/CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn/d' \
    -e '/CONFIG_PACKAGE_ntopng/d' \
    -e '/CONFIG_PACKAGE_nlbwmon/d' \
    -e '/CONFIG_PACKAGE_luci-app-nlbwmon/d' \
    -e '/CONFIG_PACKAGE_luci-app-statistics/d' \
    -e '/CONFIG_PACKAGE_adguardhome/d' \
    -e '/CONFIG_PACKAGE_smartdns/d' \
    -e '/CONFIG_PACKAGE_luci-app-smartdns/d' \
    -e '/CONFIG_PACKAGE_zerotier/d' \
    -e '/CONFIG_PACKAGE_wireguard-tools/d' \
    -e '/CONFIG_PACKAGE_banip/d' \
    -e '/CONFIG_PACKAGE_luci-app-banip/d' \
    -e '/CONFIG_PACKAGE_luci-app-ttyd/d' \
    -e '/CONFIG_PACKAGE_luci-app-wol/d' \
    -e '/CONFIG_PACKAGE_luci-app-watchcat/d' \
    -e '/CONFIG_PACKAGE_luci-app-sqm/d' \
    "${CONFIG_FILE}"

cat >> "${CONFIG_FILE}" <<'EOF'

# BEGIN R5C CUSTOM PACKAGES

# ==================================================
# NanoPi R5C company build
# FriendlyWrt 25.12 / Docker edition
# ==================================================

# --------------------------------------------------
# Docker / container
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

# 新版 OpenWrt 的 WireGuard 内核支持通常已集成，
# 保留用户空间管理工具即可。
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_luci-i18n-wireguard-zh-cn=y

# --------------------------------------------------
# Security
# --------------------------------------------------
CONFIG_PACKAGE_banip=y
CONFIG_PACKAGE_luci-app-banip=y
CONFIG_PACKAGE_luci-i18n-banip-zh-cn=y

# CrowdSec 在不同 FriendlyWrt feeds 中可用性不稳定，
# 暂不直接编入固件，建议之后使用 Docker 部署。
# CONFIG_PACKAGE_crowdsec is not set
# CONFIG_PACKAGE_crowdsec-firewall-bouncer is not set
# CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer is not set

# --------------------------------------------------
# Passwall
# --------------------------------------------------
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y

# FriendlyWrt 25.12 使用 firewall4，选择 nftables 透明代理
CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y
# CONFIG_PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy is not set

# 保留常用代理内核
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=y

# 保留常用插件
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin=y

# 关闭当前下载失败的 ShadowsocksR Libev
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set

# 关闭不需要的大型或低频组件
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_NaiveProxy is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadow_TLS is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray_Plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy is not set

# 再次明确关闭 SSR 二进制包
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
# SQM / latency control
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
# Storage support for Docker
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

# --------------------------------------------------
# Optional root password hash
# --------------------------------------------------
#
# 不要在公开 GitHub 仓库中写明文密码。
#
# 可以在 Linux 或 WSL 中生成 SHA-512 密码哈希：
#
# openssl passwd -6 '你的密码'
#
# 然后把输出内容替换到下面 ROOT_HASH 中。
#
# 示例格式：
# ROOT_HASH='$6$xxxx$xxxxxxxxxxxxxxxx'
#
ROOT_HASH='REPLACE_WITH_SHA512_PASSWORD_HASH'

if [ "${ROOT_HASH}" != 'REPLACE_WITH_SHA512_PASSWORD_HASH' ]; then
    sed -i "s#^root:[^:]*:#root:${ROOT_HASH}:#" /etc/shadow
fi

exit 0
EOF

chmod +x "${FWRT_DIR}/files/etc/uci-defaults/99-r5c-custom"

# --------------------------------------------------
# Final cleanup of SSR selections
# --------------------------------------------------

echo ">>> Enforce ShadowsocksR Libev disabled"

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

echo "=================================================="
echo " R5C custom configuration completed successfully"
echo " LAN address: 192.168.166.1"
echo " Passwall SSR Libev: disabled"
echo "=================================================="
