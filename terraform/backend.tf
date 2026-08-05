terraform {
  # Partial configuration: the bucket is supplied by scripts/up.sh via
  # -backend-config=bucket=... so the state survives `down.sh` + a later
  # `up.sh` from a completely fresh machine.
  backend "s3" {
    key     = "passw1/tokyo.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
  }
}
