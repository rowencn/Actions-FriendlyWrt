#!/bin/bash
set -e

echo "===== Custom FriendlyWrt config for NanoPi R5C ====="

# 减少不必要输出
sed -i -e '/CONFIG_MAKE_TOOLCHAIN=y/d' configs/rockchip/01-nanopi || true
sed -i -e 's/CONFIG_IB=y/# CONFIG_IB is not set/g' configs/rockchip/01-nanopi || true
sed -i -e 's/CONFIG_SDK=y/# CONFIG_SDK is not set/g' configs/rockchip/01-nanopi || true

# 添加 Passwall 第三方源码
cd friendlywrt/package

if [ ! -d passwall ]; then
    git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall.git passwall
fi

if [ ! -d passwall-packages ]; then
    git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages.git passwall-packages
fi

cd ../..

# 添加软件包
cat >> configs/rockchip/01-nanopi <<'EOF'

# =========================
# NanoPi R5C Company Build
# =========================

# Docker / 容器
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker-compose=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y

# 网络监控
CONFIG_PACKAGE_ntopng=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_nlbwmon=y
CONFIG_PACKAGE_luci-app-statistics=y

# DNS
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_smartdns=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-i18n-smartdns-zh-cn=y

# VPN / 组网
CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_luci-app-wireguard=y

# 安全
CONFIG_PACKAGE_banip=y
CONFIG_PACKAGE_luci-app-banip=y
CONFIG_PACKAGE_crowdsec=y
CONFIG_PACKAGE_crowdsec-firewall-bouncer=y
CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer=y

# 代理
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y

# 运维插件
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_attendedsysupgrade-common=y
CONFIG_PACKAGE_luci-app-attendedsysupgrade=y

# 网络优化
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_sqm-scripts=y

# 常用工具
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_btop=y
CONFIG_PACKAGE_iftop=y
CONFIG_PACKAGE_iptraf-ng=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_vim=y
CONFIG_PACKAGE_git=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_mc=y
CONFIG_PACKAGE_tree=y
CONFIG_PACKAGE_tmux=y
CONFIG_PACKAGE_screen=y
EOF

# 默认配置
mkdir -p friendlywrt/files/etc/uci-defaults

cat > friendlywrt/files/etc/uci-defaults/99-custom-defaults <<'EOF'
#!/bin/sh

# LAN IP
uci set network.lan.ipaddr='192.168.166.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# 开启 SSH
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci commit dropbear

# 修改 root 密码
# 把 YourStrongPassword 改成你自己的密码
echo -e "YourStrongPassword\nYourStrongPassword" | passwd root

exit 0
EOF

chmod +x friendlywrt/files/etc/uci-defaults/99-custom-defaults

echo "===== Custom config finished ====="
