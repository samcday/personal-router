#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

# Following ENV vars must be set:
# SSID
# WIFI_PASSWORD
# ROOT_PW

# Misc bits of config
export IPADDR="${IPADDR:-172.22.2.1}"
export NAME="${NAME:-personal-router}"
export TZ="${TZ:-Europe/Berlin}"

if [[ ! -f _build/.setup ]]; then
  mkdir -p _build/
  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/23.05.2/targets/ipq40xx/generic/openwrt-imagebuilder-23.05.2-ipq40xx-generic.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C _build/ -Jxvf -
  touch _build/.setup
fi

for f in $(find files/ -type f); do
  mkdir -p $(dirname _build/$f)
  cp $f _build/$f
done

mkdir -p _build/files/etc/uci-defaults

cat > _build/files/etc/uci-defaults/system <<HERE
set -uexo pipefail
uci -q batch <<EOI
set system.@system[0].zonename='${TZ}'
set system.@system[0].hostname='${NAME}'
commit system
set network.lan.ipaddr='${IPADDR}'
commit network
EOI
ntpd -q -p 0.openwrt.pool.ntp.org
HERE


cat > _build/files/etc/uci-defaults/root-pw <<HERE
set -uexo pipefail
passwd root <<EOP
${ROOT_PW}
${ROOT_PW}
EOP
HERE

cat > _build/files/etc/uci-defaults/wifi <<HERE
set -uexo pipefail
uci -q batch << EOI
set wireless.@wifi-device[0].disabled='0'
set wireless.@wifi-device[1].disabled='0'
set wireless.@wifi-iface[0].ssid='${SSID}'
set wireless.@wifi-iface[0].encryption=sae
set wireless.@wifi-iface[0].key="${WIFI_PASSWORD}"
set wireless.@wifi-iface[1].ssid='${SSID}'
set wireless.@wifi-iface[1].encryption=sae
set wireless.@wifi-iface[1].key="${WIFI_PASSWORD}"
commit wireless
EOI
wifi reload
HERE

# imagebuilder settings
export BIN_DIR="."
export FILES="files"
export PACKAGES=$(echo $(cat packages))
export PROFILE=avm_fritzbox-4040
export DISABLED_SERVICES="dropbear" # using openssh-server instead

(
  cd _build/
  make image PACKAGES="$PACKAGES"
)
