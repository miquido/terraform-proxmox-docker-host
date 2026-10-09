variable "proxmox_endpoint" {
  description = "URL of the Proxmox API, e.g. https://pve.example.com"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form user@realm!tokenid=secret. Prefer TF_VAR_proxmox_api_token over a tfvars file."
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "User for the SSH connection to the node (uploads the cloud-init snippet)."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Private key for that SSH connection. null = use the SSH agent."
  type        = string
  default     = null
}

variable "proxmox_node_address" {
  description = "Optional: address of the node for SSH when it differs from the endpoint (e.g. the endpoint is behind a reverse proxy)."
  type        = string
  default     = null
}

variable "aws_profile" {
  description = "AWS CLI profile to use. null = default credential chain."
  type        = string
  default     = null
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "node_name" {
  description = "Proxmox node the VM runs on."
  type        = string
}

variable "vm_id" {
  description = "Free VM ID on the cluster."
  type        = number
}

variable "name" {
  description = "VM name / hostname."
  type        = string
  default     = "docker-host-example"
}

variable "ip" {
  description = "Static IP of the VM with prefix length, e.g. 10.0.0.200/24. Must be free."
  type        = string
}

variable "gateway" {
  description = "Default gateway of the VM."
  type        = string
}

variable "domain" {
  description = "Base domain of the host, e.g. dmc.example.com. A Route53 zone is created for it; delegate it (NS records, see the nameservers output) from its parent zone, otherwise the wildcard certificate cannot be issued."
  type        = string
}

variable "acme_email" {
  description = "Email for Let's Encrypt registration."
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR allowed to call the docker-compose-runner endpoint, e.g. your office range (10.0.0.0/8). GitLab runners must be inside it."
  type        = string
}

variable "ssh_public_keys" {
  description = "Optional: SSH keys for the ubuntu user. The VM has the QEMU guest agent, so a console is also available from Proxmox."
  type        = list(string)
  default     = []
}

variable "oidc_jwks_url" {
  description = "JWKS URL of the OIDC issuer that authenticates deployments, e.g. https://gitlab.example.com/oauth/discovery/keys"
  type        = string
}

variable "oidc_audience" {
  description = "Expected audience of the OIDC token, e.g. https://gitlab.example.com"
  type        = string
}

variable "oidc_expected_subs" {
  description = "Allowed OIDC subjects (patterns), e.g. [\"project_path:my-group/**\"]"
  type        = list(string)
}

variable "enable_registry" {
  description = "Run a docker registry on the host (registry.<domain>) with generated basic-auth credentials."
  type        = bool
  default     = true
}
