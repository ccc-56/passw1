#!/usr/bin/env bash
# Shared helpers. Sourced by the other scripts, not meant to be run directly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"

# One checkout can drive several independent nodes. NODE picks the region, the
# Lightsail resource names, the state key and the clients/<node>/ directory, so
# nodes never share credentials or step on each other's state.
NODE="${NODE:-tokyo}"
case "$NODE" in
  tokyo) default_region=ap-northeast-1 ;;
  singapore) default_region=ap-southeast-1 ;;
  seoul) default_region=ap-northeast-2 ;;
  osaka) default_region=ap-northeast-3 ;;
  *) default_region="" ;;
esac
REGION="${AWS_REGION:-$default_region}"
[ -n "$REGION" ] || {
  echo "unknown NODE=$NODE: set AWS_REGION explicitly" >&2
  exit 1
}
# The state bucket lives in one region regardless of where the node runs.
STATE_REGION="${TF_STATE_REGION:-ap-northeast-1}"
# shellcheck disable=SC2034  # used by the sourcing scripts
CLIENTS_DIR="$REPO_ROOT/clients/$NODE"

export TF_VAR_region="$REGION"
export TF_VAR_availability_zone="${TF_VAR_availability_zone:-${REGION}a}"
# The original Tokyo node predates NODE and keeps its unsuffixed names.
if [ "$NODE" = tokyo ]; then
  export TF_VAR_name="${TF_VAR_name:-passw1}"
else
  export TF_VAR_name="${TF_VAR_name:-passw1-$NODE}"
fi

require() {
  for bin in "$@"; do
    command -v "$bin" >/dev/null || {
      echo "missing required command: $bin" >&2
      exit 1
    }
  done
}

account_id() {
  aws sts get-caller-identity --query Account --output text
}

state_bucket() {
  echo "${TF_STATE_BUCKET:-passw1-tfstate-$(account_id)}"
}

# The state bucket outlives `down.sh` so a later `up.sh` — even from a brand new
# machine — reuses the same keys, UUID and therefore the same client links.
ensure_state_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
    return
  fi
  echo "creating state bucket s3://$bucket"
  aws s3api create-bucket \
    --bucket "$bucket" \
    --region "$STATE_REGION" \
    --create-bucket-configuration "LocationConstraint=$STATE_REGION" >/dev/null
  aws s3api put-bucket-versioning --bucket "$bucket" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$bucket" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block --bucket "$bucket" \
    --public-access-block-configuration \
    'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
}

tf_init() {
  local bucket
  bucket="$(state_bucket)"
  ensure_state_bucket "$bucket"
  terraform -chdir="$TF_DIR" init -reconfigure -input=false \
    -backend-config="bucket=$bucket" -backend-config="region=$STATE_REGION" \
    -backend-config="key=passw1/$NODE.tfstate" >/dev/null
}

tf_out() {
  terraform -chdir="$TF_DIR" output -raw "$1"
}

# Derives the REALITY public key from the private key (raw 32-byte X25519 scalar
# in base64url). Xray only ever sees the private half; clients need the public one.
x25519_public() {
  local priv_b64u="$1" priv_b64 der pub
  # base64url -> base64, and restore the padding GNU base64 insists on.
  priv_b64="$(printf '%s' "$priv_b64u" | tr '_-' '/+')"
  while [ $((${#priv_b64} % 4)) -ne 0 ]; do priv_b64+="="; done
  der="$(mktemp)"
  pub="$(mktemp)"
  {
    # DER prefix for a PKCS#8 X25519 private key, followed by the raw 32-byte scalar.
    printf '\x30\x2e\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x6e\x04\x22\x04\x20'
    printf '%s' "$priv_b64" | base64 -d
  } >"$der"
  openssl pkey -inform DER -in "$der" -pubout -outform DER | tail -c 32 >"$pub"
  basenc --base64url <"$pub" | tr -d '='
  rm -f "$der" "$pub"
}
