# terraform-proxmox-docker-host <a href="https://miquido.com"><img align="right" src="https://cdn.miquido.dev/miquido-logo.png" width="150" /></a>

A ready-to-use Docker host on Proxmox: one VM running Traefik (wildcard certificate via DNS-01), the
OIDC-authenticated docker-compose-runner, an optional registry, WAL-G backup tooling and Ofelia for scheduled
jobs. It is the Proxmox sibling of `terraform-aws-docker-host` and `terraform-scaleway-docker-host`: all three
build their cloud-init with the same core, [`terraform-docker-host`](https://github.com/miquido/terraform-docker-host),
so the host looks and behaves the same whichever platform it runs on (same paths, same scripts).

What this module adds on top of the core, because it is Proxmox-specific:
- the cloud image, the cloud-init snippet and the VM (`bpg/proxmox`), static IP, guest agent;
- no separate data disk: `/mnt/data` lives on the root disk and is mirrored to an NFS share
  (`nas_host`/`nas_export`, rsync every 15 minutes) and restored from it when the VM is recreated;
- DNS-01 credentials through AWS IAM Roles Anywhere (`roles_anywhere_*`) or a static key (`dns_challenge_env`);
- an optional Cloudflare Tunnel for public static sites (`cloudflare_tunnel_token`, `public_domain`).

## Usage

```hcl
provider "proxmox" {
  endpoint  = "https://pve.example.com"
  api_token = "..."
  ssh { agent = true }            # needed to upload the cloud-init snippet
}

module "docker_host" {
  source = "git::https://github.com/miquido/terraform-proxmox-docker-host.git?ref=v1.0.0"

  vm_id     = 127
  name      = "dmc-docker"
  node_name = "pve1"

  ip      = "10.0.0.200/24"
  gateway = "10.0.0.1"

  domain     = "dmc.example.com"
  acme_email = "devops@example.com"
  dns_challenge_env = {             # or roles_anywhere_* instead
    AWS_ACCESS_KEY_ID     = "..."
    AWS_SECRET_ACCESS_KEY = "..."
    AWS_REGION            = "us-east-1"
  }

  oidc_jwks_url      = "https://gitlab.example.com/oauth/discovery/keys"
  oidc_audience      = "https://gitlab.example.com"
  oidc_expected_subs = "project_path:my-group/**"
  ip_allowlist       = "10.0.0.0/24"
  ssh_public_keys    = ["ssh-ed25519 AAAA..."]
}
```

## Things to know

- **cloud-init runs once.** Changing any input re-renders the snippet, which makes Terraform replace the VM
  (the `proxmox_virtual_environment_file` is replaced, so the VM is too). With `nas_host` set, the replacement
  VM restores `/mnt/data` from the NAS. Databases must then be restored from their WAL-G backups
  (`pitr-restore`, `pitr-restore-mysql` on the host), not from the file mirror, which is not a safe copy of a
  running database.
- **A restored host starts every stored stack.** The docker-compose-runner redeploys everything it finds in
  `/mnt/data/compose` when it starts. If you build a second host from a copy of production, empty
  `/mnt/data/compose` first, or it will run production workloads with production secrets.
- The host needs its own bucket/credentials for backups (`walg_env_vars`); never share them between a
  production and a test host.

## Development

```bash
make init   # run once after cloning
make readme # regenerate README.md
make lint   # lint terraform code
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.106.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | ~> 0.106.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_core"></a> [core](#module\_core) | git::https://github.com/miquido/terraform-docker-host.git | v2.0.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_download_file.ubuntu_noble](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file) | resource |
| [proxmox_virtual_environment_file.cloud_init](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.docker](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Email for Let's Encrypt ACME registration | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the Roles Anywhere credential-process call | `string` | `"eu-west-1"` | no |
| <a name="input_cloudflare_tunnel_token"></a> [cloudflare\_tunnel\_token](#input\_cloudflare\_tunnel\_token) | Cloudflare Tunnel connector token for cloudflared. Empty = skip cloudflared. | `string` | `""` | no |
| <a name="input_cpu_cores"></a> [cpu\_cores](#input\_cpu\_cores) | n/a | `number` | `2` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Root disk size in GB | `number` | `40` | no |
| <a name="input_dns_challenge_env"></a> [dns\_challenge\_env](#input\_dns\_challenge\_env) | Env vars for Traefik Route53 DNS challenge (static IAM key). Mutually exclusive in practice with roles\_anywhere\_trust\_anchor\_arn — the AWS SDK's env-var credentials take priority over the shared config profile, so setting both silently keeps using this one. Leave empty ({}) to actually use Roles Anywhere. | `map(string)` | `{}` | no |
| <a name="input_docker_compose_runner_image"></a> [docker\_compose\_runner\_image](#input\_docker\_compose\_runner\_image) | n/a | `string` | `"ghcr.io/miquido/gitlab-docker-compose-host:v1.4.0"` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Base domain for Traefik (e.g. dmc.example.com) | `string` | n/a | yes |
| <a name="input_enable_registry"></a> [enable\_registry](#input\_enable\_registry) | Run the built-in docker registry on the host (registry.<domain>). Set registry\_htpasswd as well: without it anyone who can reach the host can push images that the docker-compose-runner then pulls. | `bool` | `false` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | Default gateway for the VM (e.g. 10.10.0.1) | `string` | n/a | yes |
| <a name="input_image_datastore"></a> [image\_datastore](#input\_image\_datastore) | Proxmox datastore for VM disk | `string` | `"local"` | no |
| <a name="input_ip"></a> [ip](#input\_ip) | Static IP with prefix length in CIDR notation (e.g. 10.0.0.10/24) | `string` | n/a | yes |
| <a name="input_ip_allowlist"></a> [ip\_allowlist](#input\_ip\_allowlist) | CIDR allowed to hit docker-compose-runner | `string` | `"0.0.0.0/0"` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory in MB | `number` | `4096` | no |
| <a name="input_name"></a> [name](#input\_name) | VM name / hostname | `string` | n/a | yes |
| <a name="input_nas_export"></a> [nas\_export](#input\_nas\_export) | NFS export path for this VM's /mnt/data mirror (e.g. /docker-host) | `string` | `"/docker-host"` | no |
| <a name="input_nas_host"></a> [nas\_host](#input\_nas\_host) | NFS server IP/hostname (the real address, not a name that goes through a reverse proxy) exporting the NFS share used as periodic /mnt/data backup target. Empty = disabled. | `string` | `""` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node name | `string` | n/a | yes |
| <a name="input_oidc_audience"></a> [oidc\_audience](#input\_oidc\_audience) | Expected OIDC audience | `string` | n/a | yes |
| <a name="input_oidc_expected_subs"></a> [oidc\_expected\_subs](#input\_oidc\_expected\_subs) | Allowed OIDC subjects (patterns accepted by the docker-compose-runner, e.g. project\_path:my-group/**) | `list(string)` | n/a | yes |
| <a name="input_oidc_jwks_url"></a> [oidc\_jwks\_url](#input\_oidc\_jwks\_url) | JWKS URL for docker-compose-runner OIDC | `string` | n/a | yes |
| <a name="input_public_domain"></a> [public\_domain](#input\_public\_domain) | Domain for opt-in public exposure of static sites via the Cloudflare tunnel (e.g. example.dev). Empty = disabled. | `string` | `""` | no |
| <a name="input_registry_htpasswd"></a> [registry\_htpasswd](#input\_registry\_htpasswd) | htpasswd entries (bcrypt, comma-separated for several users) protecting the built-in registry with basic auth. Requires enable\_registry, registry\_username and registry\_password. | `string` | `""` | no |
| <a name="input_registry_password"></a> [registry\_password](#input\_registry\_password) | Password for registry\_username. | `string` | `""` | no |
| <a name="input_registry_url"></a> [registry\_url](#input\_registry\_url) | n/a | `string` | `""` | no |
| <a name="input_registry_username"></a> [registry\_username](#input\_registry\_username) | Username the host logs in with: to registry\_url (an external registry), or to its own registry.<domain> when registry\_htpasswd is set (must then be one of its users). | `string` | `""` | no |
| <a name="input_roles_anywhere_ca_cert"></a> [roles\_anywhere\_ca\_cert](#input\_roles\_anywhere\_ca\_cert) | CA certificate (PEM) that issued roles\_anywhere\_client\_cert — Roles Anywhere Trust Anchor's source | `string` | `""` | no |
| <a name="input_roles_anywhere_client_cert"></a> [roles\_anywhere\_client\_cert](#input\_roles\_anywhere\_client\_cert) | IAM Roles Anywhere client certificate (PEM). Empty = Roles Anywhere disabled, Traefik falls back to dns\_challenge\_env. | `string` | `""` | no |
| <a name="input_roles_anywhere_client_key"></a> [roles\_anywhere\_client\_key](#input\_roles\_anywhere\_client\_key) | Private key (PEM) for roles\_anywhere\_client\_cert | `string` | `""` | no |
| <a name="input_roles_anywhere_profile_arn"></a> [roles\_anywhere\_profile\_arn](#input\_roles\_anywhere\_profile\_arn) | Roles Anywhere Profile ARN. Not a secret. | `string` | `""` | no |
| <a name="input_roles_anywhere_role_arn"></a> [roles\_anywhere\_role\_arn](#input\_roles\_anywhere\_role\_arn) | IAM role assumed via Roles Anywhere, scoped to Route53 changes on the zone Traefik issues certs for. Not a secret. | `string` | `""` | no |
| <a name="input_roles_anywhere_trust_anchor_arn"></a> [roles\_anywhere\_trust\_anchor\_arn](#input\_roles\_anywhere\_trust\_anchor\_arn) | Roles Anywhere Trust Anchor ARN. Not a secret. Empty = Roles Anywhere disabled. | `string` | `""` | no |
| <a name="input_ssh_public_keys"></a> [ssh\_public\_keys](#input\_ssh\_public\_keys) | SSH public keys authorized for the ubuntu user | `list(string)` | `[]` | no |
| <a name="input_vm_description"></a> [vm\_description](#input\_vm\_description) | Description set on the Proxmox VM (e.g. link to the managing git repo) | `string` | `""` | no |
| <a name="input_vm_id"></a> [vm\_id](#input\_vm\_id) | Proxmox VM ID | `number` | n/a | yes |
| <a name="input_walg_env_vars"></a> [walg\_env\_vars](#input\_walg\_env\_vars) | WAL-G env vars written to /etc/docker-host/walg.env (symlinked from /home/ubuntu/walg.env). Empty map = skip. Pass WALG\_S3\_PREFIX, AWS\_ACCESS\_KEY\_ID, etc. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ip"></a> [ip](#output\_ip) | VM static IP (without prefix length) |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | Proxmox VM ID |
<!-- END_TF_DOCS -->
