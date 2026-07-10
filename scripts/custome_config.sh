#!/bin/bash
set -e

echo "===== NanoPi R5C FriendlyWrt customization ====="

CONFIG_FILE="configs/rockchip/01-nanopi"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: $CONFIG_FILE not found"
    exit 1
fi

# 不生成 SDK、ImageBuilder、Toolchain，减少编译时间和空间
sed -i '/CONFIG_MAKE_TOOLCHAIN=y/d' "$CONFIG_FILE"
sed -i 's/^CONFIG_IB=y/# CONFIG_IB is not set/' "$CONFIG_FILE"
sed -i 's/^CONFIG_SDK=y/# CONFIG_SDK is not set/' "$CONFIG_FILE"

# FriendlyWrt 源码目录检查
if [ ! -d "friendlywrt/package" ]; then
    echo "ERROR: friendlywrt/package not found"
    exit 1
fi

# 添加 Passwall
rm -rf friendlywrt/package/passwall
rm -rf friendlywrt/package/passwall-packages

git clone --depth=1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall.git \
    friendlywrt/package/passwall

git clone --depth=1 \
    https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
    friendlywrt/package/passwall-packages

# 避免重复追加配置
sed -i '/# BEGIN R5C CUSTOM PACKAGES/,/# END R5C CUSTOM PACKAGES/d' "$CONFIG_FILE"

cat >> "$CONFIG_FILE" <<'EOF'

# BEGIN R5C CUSTOM PACKAGES

# Docker
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker-compose=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y

# 网络监控
CONFIG_PACKAGE_nlbwmon=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_ntopng=y
CONFIG_PACKAGE_luci-app-statistics=y

# DNS
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_smartdns=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y

# VPN / 组网
CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_wireguard-tools=y

# 安全
CONFIG_PACKAGE_banip=y
CONFIG_PACKAGE_luci-app-banip=y

# Passwall
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y

# 运维
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_etherwake=y
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_watchcat=y
CONFIG_PACKAGE_luci-app-watchcat=y

# SQM
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_luci-app-sqm=y

# 命令行工具
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

# END R5C CUSTOM PACKAGES
EOF

# 创建首次启动配置
mkdir -p friendlywrt/files/etc/uci-defaults

cat > friendlywrt/files/etc/uci-defaults/99-r5c-custom <<'EOF'
#!/bin/sh

# 修改 LAN IP
uci set network.lan.ipaddr='192.168.166.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# 开启 LAN 侧 SSH 密码登录
if uci -q get dropbear.@dropbear[0] >/dev/null; then
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    uci set dropbear.@dropbear[0].Interface='lan'
    uci commit dropbear
fi

exit 0
EOF

chmod +x friendlywrt/files/etc/uci-defaults/99-r5c-custom

echo "===== NanoPi R5C customization complete ====="
