#!/bin/bash
cd "$(dirname "$0")"
set -uexo pipefail

# Following ENV vars must be set:
# SSID
# WIFI_PASSWORD
# ROOT_PW

# Secrets can be set explicitly, otherwise they're taken from my Bitwarden vault by default.
if [[ -z "${BW_SESSION:-}" ]]; then
  export BW_SESSION=$(bw unlock --raw)
fi

# Secrets
export INJECT_ENV='$WIFI_PASSWORD $TAILNET_AUTH_KEY $ROOT_PW $BOOT_TOKEN'

# Misc bits of config
export IPADDR="${IPADDR:-172.22.2.1}"
export HOSTNAME="${HOSTNAME:-personal-router}"
export INJECT_ENV="$INJECT_ENV $(echo '$HOSTNAME $SSID $IPADDR')"

if [[ ! -f _build/.setup ]]; then
  mkdir -p _build/
  curl -s --retry 2 --fail -L https://downloads.openwrt.org/releases/22.03.5/targets/ipq40xx/generic/openwrt-imagebuilder-22.03.5-ipq40xx-generic.Linux-x86_64.tar.xz | \
    tar --strip-components=1 -C _build/ -Jxvf -
  touch _build/.setup
fi

for f in $(find files/ -type f); do
  mkdir -p $(dirname _build/$f)
  envsubst "$INJECT_ENV" < $f > _build/$f
done

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
