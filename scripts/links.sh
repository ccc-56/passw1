#!/usr/bin/env bash
# Prints client share links (VLESS-REALITY + Hysteria2) for the running node
# and writes local client files. Safe to run any time; reads everything from
# Terraform state.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require terraform aws openssl basenc jq

tf_init

IP="$(tf_out public_ip)"
UUID="$(tf_out uuid)"
PORT="$(tf_out proxy_port)"
SNI="$(tf_out reality_server_name)"
SID="$(tf_out reality_short_id)"
PBK="$(x25519_public "$(tf_out reality_private_key)")"
HY_PORT="$(tf_out hysteria_port)"
HY_USER="$(tf_out hysteria_user)"
HY_PASS="$(tf_out hysteria_password)"
PIN="$(hysteria_pin)"
TAG="${LINK_TAG:-passw1-$NODE}"

# Percent-encode the few URI-hostile characters that could appear in a
# Hysteria2 password or username (both are [A-Za-z0-9-] here, but stay safe).
urlencode() {
  jq -rn --arg s "$1" '$s | @uri'
}

LINK="vless://$UUID@$IP:$PORT?encryption=none&security=reality&sni=$SNI&fp=chrome&pbk=$PBK&sid=$SID&type=tcp&flow=xtls-rprx-vision#$TAG"
# insecure=1 is required because the certificate is self-signed; pinSHA256
# is what actually authenticates the server for clients that support it.
HY2="hysteria2://$(urlencode "$HY_USER"):$(urlencode "$HY_PASS")@$IP:$HY_PORT/?sni=$SNI&insecure=1&pinSHA256=$PIN#$TAG-hy2"

OUT="$CLIENTS_DIR"
mkdir -p "$OUT"
printf '%s\n' "$LINK" >"$OUT/share-link.txt"
printf '%s\n%s\n' "$LINK" "$HY2" >"$OUT/share-links.txt"
chmod 600 "$OUT/share-link.txt" "$OUT/share-links.txt"

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

# Official hysteria client config, also used by scripts/verify.sh.
cat >"$OUT/hysteria-client.yaml" <<YAML
server: $IP:$HY_PORT
auth: $HY_USER:$HY_PASS
tls:
  sni: $SNI
  insecure: true
  pinSHA256: "$PIN"
socks5:
  listen: 127.0.0.1:${HY_SOCKS_PORT:-10809}
http:
  listen: 127.0.0.1:${HY_HTTP_PORT:-10810}
YAML
chmod 600 "$OUT/xray-client.json" "$OUT/hysteria-client.yaml"

echo
echo "node        : $NODE $IP (vless ${PORT}/tcp, hysteria2 ${HY_PORT}/udp, sni=$SNI)"
echo "vless       : $LINK"
echo "hysteria2   : $HY2"
echo
echo "wrote clients/$NODE/{share-links.txt,xray-client.json,hysteria-client.yaml} (git-ignored)"
if command -v qrencode >/dev/null; then
  for link in "$LINK" "$HY2"; do
    echo
    echo "$link"
    qrencode -t ANSIUTF8 "$link"
  done
fi
