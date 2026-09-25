locals {
  reality_private_key = trimsuffix(replace(replace(random_bytes.reality_key.base64, "+", "-"), "/", "_"), "=")

  reality_host = split(":", var.reality_dest)[0]

  # Same bootstrap script the Lightsail root feeds to cloud-init, run here over
  # SSH instead. Credentials are generated once and kept in state exactly like
  # the AWS nodes, so scripts/links.sh works unchanged.
  bootstrap = templatefile("${path.module}/../terraform/templates/user-data.sh.tftpl", {
    uuid                = random_uuid.user.result
    hysteria_user       = var.hysteria_user
    hysteria_password   = random_password.hysteria.result
    hysteria_port       = var.hysteria_port
    hysteria_cert_pem   = tls_self_signed_cert.hysteria.cert_pem
    hysteria_key_pem    = tls_private_key.hysteria.private_key_pem
    hysteria_masquerade = "https://${local.reality_host}/"
    reality_private_key = local.reality_private_key
    reality_short_id    = random_bytes.short_id.hex
    reality_dest        = var.reality_dest
    reality_server_name = var.reality_server_names[0]
    server_names        = var.reality_server_names
    proxy_port          = var.proxy_port
  })
}

resource "random_bytes" "reality_key" {
  length = 32
}

resource "random_bytes" "short_id" {
  length = 4
}

resource "random_uuid" "user" {}

resource "random_password" "hysteria" {
  length  = 24
  special = false
}

resource "tls_private_key" "hysteria" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "hysteria" {
  private_key_pem = tls_private_key.hysteria.private_key_pem

  subject {
    common_name = var.reality_server_names[0]
  }
  dns_names             = var.reality_server_names
  validity_period_hours = 24 * 365 * 10
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

# Re-runs the bootstrap whenever the rendered script (config, keys, ports) or
# the target host changes. The script is idempotent, so a rerun is a config push.
resource "terraform_data" "bootstrap" {
  triggers_replace = [var.host_ip, sha256(local.bootstrap)]

  connection {
    type        = "ssh"
    host        = var.host_ip
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    timeout     = "3m"
  }

  provisioner "file" {
    content     = "#!/bin/bash\nset -e\n${local.bootstrap}"
    destination = "/tmp/passw1-bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/passw1-bootstrap.sh",
      "sudo sh -c '/tmp/passw1-bootstrap.sh >/var/log/passw1-bootstrap.log 2>&1' || { sudo tail -50 /var/log/passw1-bootstrap.log; exit 1; }",
      "rm -f /tmp/passw1-bootstrap.sh",
    ]
  }
}
