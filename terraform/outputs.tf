output "public_ip" {
  description = "Static IPv4 address of the node."
  value       = aws_lightsail_static_ip.node.ip_address
}

output "uuid" {
  description = "VLESS user id."
  value       = random_uuid.user.result
}

output "reality_private_key" {
  description = "REALITY X25519 private key (base64url, no padding)."
  value       = local.reality_private_key
  sensitive   = true
}

output "reality_short_id" {
  description = "REALITY shortId."
  # random_bytes marks all of its attributes sensitive; a shortId is part of the
  # public share link, so unwrap it to keep the output printable.
  value = nonsensitive(random_bytes.short_id.hex)
}

output "reality_dest" {
  value = var.reality_dest
}

output "reality_server_name" {
  value = var.reality_server_names[0]
}

output "proxy_port" {
  value = var.proxy_port
}

output "ssh_private_key" {
  description = "Private key for ubuntu@public_ip."
  value       = aws_lightsail_key_pair.node.private_key
  sensitive   = true
}
