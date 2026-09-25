variable "region" {
  description = "AWS region hosting the Lightsail node. Tokyo gives the lowest latency from mainland China."
  type        = string
  default     = "ap-northeast-1"
}

variable "availability_zone" {
  description = "Lightsail availability zone, must live inside var.region."
  type        = string
  default     = "ap-northeast-1a"
}

variable "name" {
  description = "Name prefix for every resource."
  type        = string
  default     = "passw1"
}

variable "bundle_id" {
  description = <<-EOT
    Lightsail bundle. nano_3_0 = 0.5 GB RAM / 2 vCPU / 1 TB egress for $5 per month,
    which is the cheapest option that still includes bundled bandwidth
    (plain EC2 charges ~$0.114/GB out of Tokyo beyond the 100 GB free tier).
  EOT
  type        = string
  default     = "nano_3_0"
}

variable "blueprint_id" {
  description = "Lightsail OS blueprint."
  type        = string
  default     = "ubuntu_24_04"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to reach port 22. Narrow this to your own IP when you can."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "proxy_port" {
  description = "Public port the VLESS-REALITY inbound listens on."
  type        = number
  default     = 443
}

variable "hysteria_port" {
  description = <<-EOT
    Public UDP port the Hysteria2 inbound listens on. Using 443/udp makes the
    traffic look like HTTP/3 to the same site REALITY impersonates on 443/tcp.
  EOT
  type        = number
  default     = 443
}

variable "hysteria_user" {
  description = "Hysteria2 username; the password is generated and kept in state."
  type        = string
  default     = "passw1"
}

variable "reality_dest" {
  description = <<-EOT
    Host:port REALITY forwards non-proxy traffic to, i.e. the site the node
    impersonates. Must be reachable from Tokyo, speak TLS 1.3 + h2, and not be
    a CDN edge that is already blocked in China. Hysteria2 masquerades as the
    same site over HTTP/3.
  EOT
  type        = string
  default     = "www.lovelive-anime.jp:443"
}

variable "reality_server_names" {
  description = "SNI values accepted by the REALITY inbound. Must match var.reality_dest's certificate."
  type        = list(string)
  default     = ["www.lovelive-anime.jp"]
}

variable "tags" {
  description = "Extra tags applied to the Lightsail resources."
  type        = map(string)
  default     = {}
}
