set -ueo pipefail

# very simple wrapper that uses bitwarden cli (https://bitwarden.com/help/cli/) to provide env used by build-image.sh
# (wifi password, root password, etc)
# example:
# $ eval $(./bitwarden-env.sh sam-deskwart)

result=$(bw list items --search $1)
count=$(jq '. | length' <<< "$result")
if [[ "$count" != "1" ]]; then
  echo "ERROR: search term should result in 1 match, got $count"
  exit 1
fi

username=$(jq -r '.[0].login.username' <<< "$result")
if [[ "$username" != "root" ]]; then
  echo "ERROR: username of entry should be 'root', got '$username'"
  exit 1
fi

cat <<HERE
export ROOT_PW=$(jq '.[0].login.password' <<< "$result")
export WIFI_PASSWORD=$(jq '.[0].login.password' <<< "$result")
export IPADDR=$(jq .'[0].login.uris[0].uri' <<< "$result")
HERE

for (( c=0; c<$(jq '.[0].fields | length' <<< "$result"); c++)); do
  echo export $(jq -r ".[0].fields[${c}].name" <<< "$result")=$(jq ".[0].fields[${c}].value" <<< "$result")
done
