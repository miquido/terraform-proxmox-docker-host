terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  # The API cannot upload the cloud-init snippet, so the provider also needs SSH to the node.
  ssh {
    agent       = var.proxmox_ssh_private_key_path == null
    username    = var.proxmox_ssh_username
    private_key = var.proxmox_ssh_private_key_path == null ? null : file(pathexpand(var.proxmox_ssh_private_key_path))

    dynamic "node" {
      for_each = var.proxmox_node_address == null ? [] : [var.proxmox_node_address]
      content {
        name    = var.node_name
        address = node.value
      }
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # null = the default credential chain (AWS_PROFILE, SSO, instance role, ...)

  # Tags every resource with where it came from, so a stray one in the console can be traced back.
  default_tags {
    tags = {
      ManagedBy  = "terraform"
      Repository = "https://github.com/miquido/terraform-proxmox-docker-host"
      Example    = "examples/complete"
    }
  }
}
