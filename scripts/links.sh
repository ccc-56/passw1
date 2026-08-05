#!/usr/bin/env bash
# Prints client share links for the running node and writes local client files.
# Safe to run any time; reads everything from Terraform state.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require terraform aws openssl basenc

tf_init

IP="$(tf_out public_ip)"
UUID="$(tf_out uuid)"
PORT="$(tf_out proxy_port)"
SNI="$(tf_out reality_server_name)"
SID="$(tf_out reality_short_id)"
PBK="$(x25519_public "$(tf_out reality_private_key)")"
TAG="${LINK_TAG:-passw1-tokyo}"

LINK="vless://$UUID@$IP:$PORT?encryption=none&security=reality&sni=$SNI&fp=chrome&pbk=$PBK&sid=$SID&type=tcp&flow=xtls-rprx-vision#$TAG"

OUT="$REPO_ROOT/clients"
mkdir -p "$OUT"
printf '%s\n' "$LINK" >"$OUT/share-link.txt"
chmod 600 "$OUT/share-link.txt"

# sing-box / Clash.Meta users can import the share link directly; this JSON is
# for xray-core clients and for scripts/verify.sh.
cat >"$OUT/xray-client.json" <<JSON
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "socks",
      "listen": "127.0.0.1",
      "port": ${SOCKS_PORT:-10808},
      "protocol": "socks",
      "settings": { "udp": true }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$IP",
            "port": $PORT,
            "users": [
              { "id": "$UUID", "encryption": "none", "flow": "xtls-rprx-vision" }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "serverName": "$SNI",
          "fingerprint": "chrome",
          "publicKey": "$PBK",
          "shortId": "$SID"
        }
      }
    }
  ]
}
JSON
chmod 600 "$OUT/xray-client.json"

echo
echo "node        : $IP:$PORT (REALITY sni=$SNI)"
echo "share link  : $LINK"
echo
echo "wrote clients/share-link.txt and clients/xray-client.json (git-ignored)"
if command -v qrencode >/dev/null; then
  qrencode -t ANSIUTF8 "$LINK"
fi
