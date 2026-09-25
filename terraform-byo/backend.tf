terraform {
  # Partial configuration: bucket, region and key (passw1/<node>.tfstate) are
  # supplied by scripts/common.sh via -backend-config so the state survives
  # `down.sh` + a later `up.sh` from a completely fresh machine, and each NODE
  # gets its own state file.
  backend "s3" {
    encrypt = true
  }
}
