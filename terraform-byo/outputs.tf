output "public_ip" {
  value = var.host_ip
}

output "uuid" {
  value = random_uuid.user.result
}

output "hysteria_user" {
  value = var.hysteria_user
}

output "hysteria_password" {
  value     = random_password.hysteria.result
  sensitive = true
}

output "hysteria_cert_pem" {
  value = tls_self_signed_cert.hysteria.cert_pem
}

output "hysteria_port" {
  value = var.hysteria_port
}

output "reality_private_key" {
  value     = local.reality_private_key
  sensitive = true
}

output "reality_short_id" {
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

output "ssh_user" {
  value = var.ssh_user
}

output "ssh_private_key" {
  value     = file(pathexpand(var.ssh_private_key_path))
  sensitive = true
}
