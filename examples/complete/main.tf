locals {
  registry_username = "ci"
}

resource "random_password" "registry" {
  count   = var.enable_registry ? 1 : 0
  length  = 32
  special = false
}

# bcrypt() returns a different hash on every evaluation, and any change of the cloud-init makes Terraform replace the
# VM. Keeping the first hash here (it is recomputed only when the password changes) avoids a replacement per plan.
resource "terraform_data" "registry_htpasswd" {
  count = var.enable_registry ? 1 : 0

  triggers_replace = [random_password.registry[0].result]
  input            = "${local.registry_username}:${bcrypt(random_password.registry[0].result)}"

  lifecycle {
    ignore_changes = [input]
  }
}

module "docker_host" {
  # Outside this repository use the released module:
  #   source = "git::https://github.com/miquido/terraform-proxmox-docker-host.git?ref=v1.1.0"
  source = "../.."

  vm_id     = var.vm_id
  name      = var.name
  node_name = var.node_name
  # Own copy of the image: the default name is shared with other hosts on the same datastore, and the module
  # replaces that file on apply and removes it on destroy.
  image_file_name = "noble-server-cloudimg-amd64-example.img"
  vm_description  = "Example of terraform-proxmox-docker-host, managed by Terraform"

  ip      = var.ip
  gateway = var.gateway

  domain     = var.domain
  acme_email = var.acme_email

  # DNS-01 through IAM Roles Anywhere (roles_anywhere.tf): the VM holds a client certificate, no AWS access key.
  roles_anywhere_client_cert      = tls_locally_signed_cert.client.cert_pem
  roles_anywhere_client_key       = tls_private_key.client.private_key_pem
  roles_anywhere_ca_cert          = tls_self_signed_cert.ca.cert_pem
  roles_anywhere_trust_anchor_arn = aws_rolesanywhere_trust_anchor.main.arn
  roles_anywhere_profile_arn      = aws_rolesanywhere_profile.main.arn
  roles_anywhere_role_arn         = aws_iam_role.dns_challenge.arn
  # wal-g runs from postgres's archive_command as the postgres user (gid 999), which has to read the key.
  roles_anywhere_key_gid = 999
  aws_region             = var.aws_region

  # WAL-G authenticates with the same Roles Anywhere profile (walg.tf).
  walg_env_vars = {
    AWS_SDK_LOAD_CONFIG     = "1"
    AWS_CONFIG_FILE         = "/roles-anywhere/config"
    AWS_PROFILE             = "roles-anywhere"
    AWS_REGION              = var.aws_region
    WALG_S3_PREFIX          = "s3://${aws_s3_bucket.walg.id}/walg"
    WALG_COMPRESSION_METHOD = "lz4"
  }

  ip_allowlist       = var.allowed_cidr
  ssh_public_keys    = var.ssh_public_keys
  oidc_jwks_url      = var.oidc_jwks_url
  oidc_audience      = var.oidc_audience
  oidc_expected_subs = var.oidc_expected_subs

  # Registry on the host with basic auth: the credentials are generated and exposed as outputs.
  enable_registry   = var.enable_registry
  registry_username = var.enable_registry ? local.registry_username : ""
  registry_password = var.enable_registry ? random_password.registry[0].result : ""
  registry_htpasswd = var.enable_registry ? terraform_data.registry_htpasswd[0].output : ""
}
