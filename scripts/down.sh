#!/usr/bin/env bash
# Destroys everything that costs money so the bill goes to zero.
#
# Only the AWS resources are targeted: the random_* resources holding the UUID
# and the REALITY keypair stay in state, so a later `up.sh` rebuilds the node
# with the *same* credentials and the client links you already imported keep
# working (only the IP changes).
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require terraform aws

BILLED_RESOURCES=(
  aws_lightsail_instance_public_ports.node
  aws_lightsail_static_ip_attachment.node
  aws_lightsail_instance.node
  aws_lightsail_static_ip.node
  aws_lightsail_key_pair.node
)

tf_init
terraform -chdir="$TF_DIR" destroy -input=false -auto-approve \
  "${BILLED_RESOURCES[@]/#/-target=}" "$@"

rm -f "$CLIENTS_DIR/share-link.txt" "$CLIENTS_DIR/xray-client.json"
echo "node $NODE destroyed; UUID and REALITY keys kept in s3://$(state_bucket)/passw1/$NODE.tfstate"
