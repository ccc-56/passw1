#!/usr/bin/env bash
# End-to-end check: runs a throwaway xray client against the node and confirms
# traffic actually exits through it (curl's observed IP == node IP).
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require terraform aws curl unzip openssl basenc

SOCKS_PORT="${SOCKS_PORT:-10808}"
export SOCKS_PORT
"$REPO_ROOT/scripts/links.sh" >/dev/null

BIN_DIR="$REPO_ROOT/.local"
XRAY="$BIN_DIR/xray"
if [ ! -x "$XRAY" ]; then
  mkdir -p "$BIN_DIR"
  if [ -z "${XRAY_VERSION:-}" ]; then
    # Parse in two steps: piping curl into grep -m1 makes curl die on SIGPIPE.
    release_json="$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest)"
    XRAY_VERSION="$(printf '%s' "$release_json" | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
  fi
  version="$XRAY_VERSION"
  echo "downloading xray-core $version"
  curl -fsSL -o "$BIN_DIR/xray.zip" \
    "https://github.com/XTLS/Xray-core/releases/download/$version/Xray-linux-64.zip"
  unzip -o -q "$BIN_DIR/xray.zip" -d "$BIN_DIR" xray
  chmod +x "$XRAY"
fi

"$XRAY" run -c "$REPO_ROOT/clients/xray-client.json" >"$BIN_DIR/xray-client.log" 2>&1 &
client_pid=$!
trap 'kill $client_pid 2>/dev/null || true' EXIT
sleep 3

node_ip="$(tf_out public_ip)"
seen_ip="$(curl -fsS --max-time 25 --socks5-hostname "127.0.0.1:$SOCKS_PORT" https://api.ipify.org)"
echo "node ip: $node_ip"
echo "exit ip: $seen_ip"
[ "$node_ip" = "$seen_ip" ] || {
  echo "FAIL: traffic is not exiting through the node" >&2
  tail -20 "$BIN_DIR/xray-client.log" >&2
  exit 1
}

for url in https://www.google.com/generate_204 https://www.youtube.com https://x.com; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 \
    --socks5-hostname "127.0.0.1:$SOCKS_PORT" "$url")"
  echo "$url -> HTTP $code"
done

echo "OK: proxy works"
