# passw1

Cheap, disposable outbound proxy nodes on AWS Lightsail, running Xray-core with
**VLESS + REALITY** (443/tcp) and **Hysteria2** (443/udp) side by side. Built to
be created and destroyed on demand:
`scripts/up.sh` to bring a node online, `scripts/down.sh` to stop paying.

One checkout manages several independent nodes, selected with `NODE`:

| `NODE` | region | Lightsail name | state key |
| --- | --- | --- | --- |
| `tokyo` (default) | `ap-northeast-1` | `passw1` | `passw1/tokyo.tfstate` |
| `tokyo2` | `ap-northeast-1` | `passw1-tokyo2` | `passw1/tokyo2.tfstate` |
| `singapore` | `ap-southeast-1` | `passw1-singapore` | `passw1/singapore.tfstate` |
| `seoul` / `osaka` | `ap-northeast-2` / `-3` | `passw1-<node>` | `passw1/<node>.tfstate` |
| anything else | `AWS_REGION` (required) | `passw1-<node>` | `passw1/<node>.tfstate` |
| `dmit-hk` | — (existing VPS, `179.255.103.135`) | — | `passw1/dmit-hk.tfstate` |
| anything else + `BYO_HOST_IP` | — (existing VPS) | — | `passw1/<node>.tfstate` |

Every node has its own UUID, REALITY keypair, Hysteria2 password/certificate, SSH key and `clients/<node>/`
directory; running a script for one node never touches another.

## Cost

| item | monthly |
| --- | --- |
| Lightsail `nano_3_0` (0.5 GB / 2 vCPU, **1 TB egress included**) | $5.00 |
| Static IPv4 (while attached to a running instance) | $0.00 |
| S3 state bucket (a few KB) | ~$0.00 |

Prorated hourly, so a node that only lives for a weekend costs roughly $0.25.

Lightsail is used instead of EC2 on purpose: EC2 charges ~$0.114/GB egress from
Tokyo beyond the 100 GB free tier, i.e. streaming video from an EC2 proxy easily
costs 10–20x the instance itself. `micro_3_0` ($7, 2 TB) and `small_3_0` ($12,
3 TB) are drop-in upgrades via `bundle_id` if 1 TB is not enough.

## Why VLESS + REALITY

REALITY completes the TLS handshake against a real third-party site
(`reality_dest`), so the node presents a genuine certificate for a genuine
domain and has no TLS fingerprint of its own. No domain name, no ACME
certificate and no CDN are required, and active probing of the port sees only
the impersonated site.

## Why also Hysteria2

Mobile carriers (notably China Mobile 4G/5G) throttle or drop long-lived TCP
connections to foreign VPS ranges far more aggressively than home broadband
does, so a pure VLESS-over-TCP node can be fine on Wi-Fi and unreachable on
cellular. Hysteria2 is QUIC over UDP with its own congestion control; it
usually stays usable when TCP 443 is being interfered with. It listens on
443/udp so the traffic looks like HTTP/3 to the same site REALITY impersonates,
and unauthenticated probes get a reverse proxy of that site. The certificate is
self-signed (no domain), so clients pin its SHA-256 (`pinSHA256` in the link).

## Usage

Prerequisites: `terraform`, `aws` CLI with credentials (also for BYO hosts: the state bucket lives in S3), `openssl`, `curl`,
`unzip`, `jq`, `basenc` (coreutils). Optional: `qrencode` for a scannable QR code.

```bash
./scripts/up.sh        # create/update the Tokyo node, print vless:// and hysteria2:// links
./scripts/verify.sh    # prove traffic really exits through the node over both tcp and udp
./scripts/links.sh     # reprint the share links and rewrite clients/<node>/
./scripts/rotate-ip.sh # new IPv4 if the current one gets blocked
./scripts/ssh.sh       # shell on the node (e.g. journalctl -u xray)
./scripts/down.sh      # destroy the node, bill back to zero

NODE=singapore ./scripts/up.sh      # same lifecycle for the Singapore node
NODE=singapore ./scripts/verify.sh
NODE=singapore ./scripts/down.sh
```

### Bring-your-own host (DMIT, BandwagonHost, ...)

A VPS bought elsewhere (typically for a China-optimised route such as CN2 GIA)
can run the exact same Xray + Hysteria2 setup. `terraform-byo/` is a second
root module that generates the same credentials into the same S3 state bucket,
but instead of creating a Lightsail instance it uploads the rendered
`terraform/templates/user-data.sh.tftpl` over SSH and runs it (`terraform_data`
+ `remote-exec`; re-run whenever the template or the IP changes). Debian 12/13
and Ubuntu 22.04+ are fine. The host must allow key-based login as `root`
(or a passwordless-sudo user via `BYO_SSH_USER`) with 443/tcp+udp open.

```bash
mkdir -p clients/dmit-hk && cp ~/Downloads/id_rsa.pem clients/dmit-hk/node-key.pem && chmod 600 clients/dmit-hk/node-key.pem
NODE=dmit-hk ./scripts/up.sh          # provision over SSH, print links
NODE=dmit-hk ./scripts/verify.sh
NODE=dmit-hk ./scripts/ssh.sh

# any other VPS:
NODE=lax BYO_HOST_IP=203.0.113.7 BYO_SSH_KEY=~/.ssh/lax ./scripts/up.sh
```

The key is read at apply time only (`BYO_SSH_KEY`, default
`clients/<node>/node-key.pem`); `down.sh` and `rotate-ip.sh` refuse BYO nodes
since nothing is billed or allocated through AWS — cancel or re-IP the VPS with
its provider and rerun `up.sh`.

`clients/<node>/` (git-ignored) gets `share-links.txt` (vless + hysteria2), an
xray-core client config, a hysteria client config and the SSH private key.
Import the share links into v2rayN / Nekoray / sing-box / Shadowrocket /
Clash.Meta (Clash Verge) directly; add both entries to a `url-test` group so the
client falls back to UDP when TCP is throttled.

### State and stable credentials

Terraform state lives in `s3://passw1-tfstate-<account-id>` (created
automatically in `ap-northeast-1`, override with `TF_STATE_BUCKET` /
`TF_STATE_REGION`), one object per node: `passw1/<node>.tfstate`. `down.sh` deletes only the
billed AWS resources and leaves the UUID, REALITY keypair, Hysteria2 password
and certificate in state, so the
next `up.sh` — even from a different machine — issues the *same* credentials and
your previously imported client entry keeps working after a one-line IP edit
(or just re-import the freshly printed link).

The REALITY private key is 32 random bytes generated by Terraform; the public
key clients need is derived from it with `openssl` in `scripts/common.sh`, which
is why the server never has to report it back.

## Operational notes

- Only ports 22/tcp (`ssh_allowed_cidrs`, default open — narrow it), 443/tcp
  and 443/udp are reachable; Lightsail's default port 80 rule is removed.
- Changing anything in `user-data` (including this Hysteria2 addition) replaces
  the Lightsail instance: ~3 minutes of downtime per node, same static IP,
  same credentials.
- BBR + `fq` and enlarged TCP buffers are applied via cloud-init, which matters
  a lot on lossy China→Japan paths. A 1 GB swapfile protects the 512 MB node.
- Watch the 1 TB allowance in the Lightsail console; overage is $0.09/GB.
- If throughput collapses but the port is still open, the IP is likely throttled
  rather than blocked — `rotate-ip.sh` is the fast fix.
- Sensitive values (`reality_private_key`, `hysteria_password`, `ssh_private_key`) are Terraform
  outputs marked sensitive and stored in the encrypted state bucket. Anyone with
  the share link has full use of the node; treat it as a password.
