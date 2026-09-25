variable "host_ip" {
  description = "Public IPv4 of an existing VPS (DMIT, BandwagonHost, ...) to provision over SSH."
  type        = string
}

variable "ssh_user" {
  description = "SSH login user on the host; needs passwordless sudo if not root."
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for ssh_user. Kept out of state; only its content is read at apply time."
  type        = string
}

variable "proxy_port" {
  description = "Public port the VLESS-REALITY inbound listens on."
  type        = number
  default     = 443
}

variable "hysteria_port" {
  description = "Public UDP port the Hysteria2 inbound listens on."
  type        = number
  default     = 443
}

variable "hysteria_user" {
  description = "Hysteria2 username; the password is generated and kept in state."
  type        = string
  default     = "passw1"
}

variable "reality_dest" {
  description = "Host:port REALITY forwards non-proxy traffic to; must be reachable from the host."
  type        = string
  default     = "www.lovelive-anime.jp:443"
}

variable "reality_server_names" {
  description = "SNI values accepted by the REALITY inbound. Must match var.reality_dest's certificate."
  type        = list(string)
  default     = ["www.lovelive-anime.jp"]
}
