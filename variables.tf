variable "vm_id" {
  type        = number
  description = "Proxmox VM ID"
}

variable "image_datastore" {
  type        = string
  description = "Proxmox datastore for VM disk"
  default     = "local"
}

variable "name" {
  type        = string
  description = "VM name / hostname"
}

variable "node_name" {
  type        = string
  description = "Proxmox node name"
}

variable "vm_description" {
  type        = string
  description = "Description set on the Proxmox VM (e.g. link to the managing git repo)"
  default     = ""
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys authorized for the ubuntu user"
  default     = []
}

variable "ip" {
  type        = string
  description = "Static IP with prefix length in CIDR notation (e.g. 10.0.0.10/24)"
}

variable "gateway" {
  type        = string
  description = "Default gateway for the VM (e.g. 10.10.0.1)"
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory" {
  type        = number
  default     = 4096
  description = "Memory in MB"
}

variable "disk_size" {
  type        = number
  default     = 40
  description = "Root disk size in GB"
}

variable "domain" {
  type        = string
  description = "Base domain for Traefik (e.g. dmc.example.com)"
}

variable "acme_email" {
  type        = string
  description = "Email for Let's Encrypt ACME registration"
}

variable "dns_challenge_env" {
  type        = map(string)
  sensitive   = true
  description = "Env vars for Traefik Route53 DNS challenge (static IAM key). Mutually exclusive in practice with roles_anywhere_trust_anchor_arn — the AWS SDK's env-var credentials take priority over the shared config profile, so setting both silently keeps using this one. Leave empty ({}) to actually use Roles Anywhere."
  default     = {}
}

variable "roles_anywhere_client_cert" {
  type        = string
  sensitive   = true
  description = "IAM Roles Anywhere client certificate (PEM). Empty = Roles Anywhere disabled, Traefik falls back to dns_challenge_env."
  default     = ""
}

variable "roles_anywhere_client_key" {
  type        = string
  sensitive   = true
  description = "Private key (PEM) for roles_anywhere_client_cert"
  default     = ""
}

variable "roles_anywhere_ca_cert" {
  type        = string
  sensitive   = true
  description = "CA certificate (PEM) that issued roles_anywhere_client_cert — Roles Anywhere Trust Anchor's source"
  default     = ""
}

variable "roles_anywhere_trust_anchor_arn" {
  type        = string
  description = "Roles Anywhere Trust Anchor ARN. Not a secret. Empty = Roles Anywhere disabled."
  default     = ""
}

variable "roles_anywhere_profile_arn" {
  type        = string
  description = "Roles Anywhere Profile ARN. Not a secret."
  default     = ""
}

variable "roles_anywhere_role_arn" {
  type        = string
  description = "IAM role assumed via Roles Anywhere, scoped to Route53 changes on the zone Traefik issues certs for. Not a secret."
  default     = ""
}

variable "aws_region" {
  type        = string
  description = "AWS region for the Roles Anywhere credential-process call"
  default     = "eu-west-1"
}

variable "oidc_jwks_url" {
  type        = string
  description = "JWKS URL for docker-compose-runner OIDC"
}

variable "oidc_audience" {
  type        = string
  description = "Expected OIDC audience"
}

variable "oidc_expected_subs" {
  type        = list(string)
  description = "Allowed OIDC subjects (patterns accepted by the docker-compose-runner, e.g. project_path:my-group/**)"
}

variable "ip_allowlist" {
  type        = string
  description = "CIDR allowed to hit docker-compose-runner"
  default     = "0.0.0.0/0"
}

variable "docker_compose_runner_image" {
  type    = string
  default = "ghcr.io/miquido/gitlab-docker-compose-host:v1.4.0"
}

variable "nas_host" {
  type        = string
  description = "NFS server IP/hostname (the real address, not a name that goes through a reverse proxy) exporting the NFS share used as periodic /mnt/data backup target. Empty = disabled."
  default     = ""
}

variable "nas_export" {
  type        = string
  description = "NFS export path for this VM's /mnt/data mirror (e.g. /docker-host)"
  default     = "/docker-host"
}

variable "walg_env_vars" {
  type        = map(string)
  sensitive   = true
  description = "WAL-G env vars written to /etc/docker-host/walg.env (symlinked from /home/ubuntu/walg.env). Empty map = skip. Pass WALG_S3_PREFIX, AWS_ACCESS_KEY_ID, etc."
  default     = {}
}

variable "registry_url" {
  type    = string
  default = ""
}

variable "cloudflare_tunnel_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare Tunnel connector token for cloudflared. Empty = skip cloudflared."
  default     = ""
}

variable "public_domain" {
  type        = string
  description = "Domain for opt-in public exposure of static sites via the Cloudflare tunnel (e.g. example.dev). Empty = disabled."
  default     = ""
}

variable "registry_username" {
  type        = string
  description = "Username the host logs in with: to registry_url (an external registry), or to its own registry.<domain> when registry_htpasswd is set (must then be one of its users)."
  default     = ""
}

variable "registry_password" {
  type        = string
  sensitive   = true
  description = "Password for registry_username."
  default     = ""
}

variable "enable_registry" {
  type        = bool
  description = "Run the built-in docker registry on the host (registry.<domain>). Set registry_htpasswd as well: without it anyone who can reach the host can push images that the docker-compose-runner then pulls."
  default     = false
}

variable "registry_htpasswd" {
  type        = string
  sensitive   = true
  description = "htpasswd entries (bcrypt, comma-separated for several users) protecting the built-in registry with basic auth. Requires enable_registry, registry_username and registry_password."
  default     = ""
}
