#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

# TODO: configurable and include in _build/.setup check, mebbe?
export VERSION=23.05.2

export TARGET=${TARGET:-ipq40xx/generic}
export PROFILE=${PROFILE:-avm_fritzbox-4040}

# Misc bits of config
export IPADDR="${IPADDR:-172.22.2.1}"
export TZ="${TZ:-Europe/Berlin}"

if [[ ! -f _build/${TARGET}/.setup ]]; then
  mkdir -p _build/${TARGET}

  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/${VERSION}/targets/${TARGET}/openwrt-imagebuilder-${VERSION}-${TARGET//\//-}.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C _build/${TARGET} -Jxvf -
  touch _build/${TARGET}/.setup
fi

if [[ ! -d _build/petname ]]; then
  (
    pushd _build
    git clone https://github.com/dustinkirkland/petname.git
  )
fi

(
  pushd _build/petname
  git pull
)

rm -rf _build/files
mkdir -p _build/files
rsync -avz _build/petname/usr _build/files/

for f in $(find files/ -type f); do
  mkdir -p $(dirname _build/$f)
  cp $f _build/$f
done

mkdir -p _build/files/etc/uci-defaults

cat > _build/files/etc/uci-defaults/tz <<HERE
set -uexo pipefail
uci -q batch <<EOI
set system.@system[0].zonename='${TZ}'
commit system
set network.lan.ipaddr='${IPADDR}'
commit network
EOI
ntpd -q -p 0.openwrt.pool.ntp.org
HERE

if [[ -n "${WIFI_PASSWORD:-}" ]]; then
  echo -n "${WIFI_PASSWORD}" > _build/files/etc/wifi-pass
fi
if [[ -n "${HOSTNAME:-}" ]]; then
  echo -n "${HOSTNAME}" > _build/files/etc/hostname
fi

if [[ -n "${ROOT_PW:-}" ]]; then
  cat > _build/files/etc/uci-defaults/root-pw <<HERE
set -uexo pipefail
passwd root <<EOP
${ROOT_PW}
${ROOT_PW}
EOP
HERE
fi

# imagebuilder settings
export BIN_DIR="`pwd`"
export FILES="`pwd`/_build/files"
export PACKAGES=$(echo $(cat packages))
export DISABLED_SERVICES="dropbear" # using openssh-server instead

(
  cd _build/${TARGET}
  make image PACKAGES="$PACKAGES"
)

echo done, image location follows
echo `pwd`/_build/${TARGET}/bin/targets/${TARGET}/openwrt-${VERSION}-${TARGET//\//-}-${PROFILE}-squashfs-sysupgrade.bin
