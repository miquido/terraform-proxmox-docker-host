terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106.0"
    }
  }
}

locals {
  # Strip prefix length for Route53 (e.g. "10.0.0.10/24" → "10.0.0.10")
  vm_ip = split("/", var.ip)[0]

  roles_anywhere_enabled = var.roles_anywhere_trust_anchor_arn != ""

  roles_anywhere_config_content = templatefile("${path.module}/templates/aws-roles-anywhere-config.tftpl", {
    trust_anchor_arn = var.roles_anywhere_trust_anchor_arn
    profile_arn      = var.roles_anywhere_profile_arn
    role_arn         = var.roles_anywhere_role_arn
    aws_region       = var.aws_region
  })

  roles_anywhere_write_files = local.roles_anywhere_enabled ? [
    {
      path    = "/home/ubuntu/aws-roles-anywhere/client-cert.pem"
      content = var.roles_anywhere_client_cert
    },
    {
      path        = "/home/ubuntu/aws-roles-anywhere/client-key.pem"
      content     = var.roles_anywhere_client_key
      permissions = "0600"
    },
    {
      path    = "/home/ubuntu/aws-roles-anywhere/ca-cert.pem"
      content = var.roles_anywhere_ca_cert
    },
    {
      path    = "/home/ubuntu/aws-roles-anywhere/config"
      content = local.roles_anywhere_config_content
    },
  ] : []

  # Official Traefik image is Alpine/musl; the AWS-built aws_signing_helper binary is
  # glibc-only — installed via gcompat in the Traefik entrypoint (roles_anywhere_entrypoint below).
  roles_anywhere_runcmd = local.roles_anywhere_enabled ? [
    # SHA-256 of release 1.8.5 (X86_64, Amzn2023) as downloaded when this was pinned; the install aborts
    # on a mismatch instead of making an unverified binary executable.
    "curl -fsSL -o /home/ubuntu/aws-roles-anywhere/aws_signing_helper https://rolesanywhere.amazonaws.com/releases/1.8.5/X86_64/Linux/Amzn2023/aws_signing_helper && echo 'beec9ed1c492d93db809890f16713e3556353294b823c2184ad4e891f1b2b54d  /home/ubuntu/aws-roles-anywhere/aws_signing_helper' | sha256sum -c - && chmod +x /home/ubuntu/aws-roles-anywhere/aws_signing_helper",
  ] : []

  public_domain_escaped_raw = replace(var.public_domain, ".", "\\.")

  # Public exposure of opt-in static sites via the Cloudflare tunnel: a separate Traefik
  # entrypoint + router, and an nginx gate that 403s tunnel hosts without a .dmc-public marker.
  tunnel_enabled = var.public_domain != "" || var.cloudflare_tunnel_token != ""

  static_extra_labels = var.public_domain != "" ? [
    "traefik.http.routers.static-tunnel.rule=HostRegexp(`^[a-z0-9-]+\\.${local.public_domain_escaped_raw}$`)",
    "traefik.http.routers.static-tunnel.entrypoints=tunnel",
    "traefik.http.routers.static-tunnel.priority=1",
    "traefik.http.routers.static-tunnel.service=static",
  ] : []

  nginx_public_gate = <<-EOF
    set $dmc_public_gate "";
    if ($host ~ \.${local.public_domain_escaped_raw}$) {
      set $dmc_public_gate "T";
    }
    if (!-f $document_root/.dmc-public) {
      set $dmc_public_gate "$${dmc_public_gate}F";
    }
    if ($dmc_public_gate = "TF") {
      return 403;
    }
    EOF

  cloudflared_service = <<-EOF
    cloudflared:
      image: cloudflare/cloudflared:2026.9.3
      command: tunnel run
      environment:
        TUNNEL_TOKEN: ${var.cloudflare_tunnel_token}
      restart: unless-stopped
      networks:
        - traefik-net
    EOF

  # NFS-backed periodic backup target (QNAP NAS). Empty nas_host = disabled.
  nas_enabled  = var.nas_host != ""
  nas_packages = local.nas_enabled ? ["nfs-common", "rsync"] : []

  nas_write_files = local.nas_enabled ? [
    {
      path    = "/etc/fstab"
      content = "${var.nas_host}:${var.nas_export} /mnt/data-nas nfs vers=4,rw,hard,timeo=50,retrans=3,_netdev 0 0\n"
      append  = true
    },
    {
      path    = "/etc/systemd/system/docker-restore.service"
      content = <<-EOF
        [Unit]
        Description=Restore /mnt/data from NAS
        # Without this, a NAS that is not mounted yet makes the restore a silent no-op and the empty
        # disk is then mirrored over the NAS copy by docker-backup.
        RequiresMountsFor=/mnt/data-nas
        Before=docker.service
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/bin/bash -c 'if [ -z "$(ls -A /mnt/data/compose 2>/dev/null)" ] && mountpoint -q /mnt/data-nas; then rsync -a --delete /mnt/data-nas/ /mnt/data/ && find /mnt/data/certs -type f -exec chmod 600 {} \;; fi'

        [Install]
        WantedBy=multi-user.target
      EOF
    },
    {
      path    = "/etc/systemd/system/docker-backup.service"
      content = <<-EOF
        [Unit]
        Description=Backup /mnt/data to NAS
        RequiresMountsFor=/mnt/data-nas
        After=network-online.target

        [Service]
        Type=oneshot
        # --delete: without it, files removed locally (or leftover cruft from a mid-restore crash, such
        # as stale InnoDB temp files, which can corrupt a later restore) accumulate on the NAS forever
        # instead of the mirror reflecting the current state.
        # Refuse to run when the NAS is not mounted or /mnt/data/compose is empty: that is a fresh or
        # failed-restore disk, and mirroring it with --delete would wipe the only copy.
        ExecStart=/bin/bash -c 'mountpoint -q /mnt/data-nas || { echo "NAS not mounted: refusing to mirror"; exit 1; }; [ -n "$(ls -A /mnt/data/compose 2>/dev/null)" ] || { echo "/mnt/data/compose is empty (fresh disk or restore did not run): refusing to overwrite the NAS copy"; exit 1; }; rsync -a --delete /mnt/data/ /mnt/data-nas/'
      EOF
    },
    {
      path    = "/etc/systemd/system/docker-backup.timer"
      content = <<-EOF
        [Unit]
        Description=Backup /mnt/data to NAS every 15 minutes

        [Timer]
        OnBootSec=15min
        OnUnitActiveSec=15min
        Persistent=true

        [Install]
        WantedBy=timers.target
      EOF
    },
  ] : []

  nas_runcmd = local.nas_enabled ? [
    "mkdir -p /mnt/data-nas",
    "mount -a",
    "systemctl daemon-reload",
    "systemctl enable docker-restore.service docker-backup.timer",
    "systemctl start docker-restore.service",
    "systemctl start docker-backup.timer",
  ] : []

  # Official Traefik image is Alpine/musl; the AWS-built aws_signing_helper binary is
  # glibc-only — installed via gcompat in the entrypoint, not here.
  roles_anywhere_entrypoint = local.roles_anywhere_enabled ? [
    "sh", "-c", "apk add --no-cache gcompat >/dev/null && exec /entrypoint.sh \"$@\"", "--",
  ] : []
  roles_anywhere_volumes = local.roles_anywhere_enabled ? ["/home/ubuntu/aws-roles-anywhere:/roles-anywhere:ro"] : []
  # The SDK finds the profile only through AWS_CONFIG_FILE (there is no ~/.aws/config in the Traefik
  # container) and needs a region for the Route53 client: the region in credential_process is not enough.
  roles_anywhere_env = local.roles_anywhere_enabled ? {
    AWS_SDK_LOAD_CONFIG = "1"
    AWS_PROFILE         = "roles-anywhere"
    AWS_CONFIG_FILE     = "/roles-anywhere/config"
    AWS_REGION          = var.aws_region
  } : {}
}

module "core" {
  source = "git::https://github.com/miquido/terraform-docker-host.git?ref=v2.0.1"

  hostname     = var.name
  vm_user      = "ubuntu"
  block_device = "" # no separate data disk on Proxmox; /mnt/data is on the root disk, mirrored to the NAS

  domain                 = var.domain
  acme_email             = var.acme_email
  dns_challenge_provider = "route53"
  dns_challenge_env      = var.dns_challenge_env

  oidc_jwks_url               = var.oidc_jwks_url
  oidc_audience               = var.oidc_audience
  oidc_expected_subs          = var.oidc_expected_subs
  ip_allowlist                = var.ip_allowlist
  docker_compose_runner_image = var.docker_compose_runner_image

  registry_url      = var.registry_url
  registry_username = var.registry_username
  registry_password = var.registry_password
  enable_registry   = var.enable_registry
  registry_htpasswd = var.registry_htpasswd

  ssh_public_keys = var.ssh_public_keys
  walg_env_vars   = var.walg_env_vars

  # Previously unconditional on this platform; Proxmox has no log shipping and no prune cron yet.
  traefik_access_log    = true
  docker_prune_schedule = ""

  traefik_entrypoint        = local.roles_anywhere_entrypoint
  traefik_extra_volumes     = local.roles_anywhere_volumes
  traefik_extra_environment = local.roles_anywhere_env
  traefik_extra_args        = local.tunnel_enabled ? ["--entrypoints.tunnel.address=:8000"] : []
  static_extra_labels       = local.static_extra_labels
  nginx_static_server_extra = var.public_domain != "" ? local.nginx_public_gate : ""
  extra_compose_services    = var.cloudflare_tunnel_token != "" ? local.cloudflared_service : ""

  extra_packages = concat(["qemu-guest-agent"], local.nas_packages)
  extra_write_files = concat(
    local.nas_write_files,
    local.roles_anywhere_write_files,
  )
  extra_runcmd = concat(
    ["systemctl enable --now qemu-guest-agent"],
    local.nas_runcmd,
    local.roles_anywhere_runcmd,
    ["chown -R ubuntu:ubuntu /mnt/data/certs /mnt/data/compose /mnt/data/static /home/ubuntu"],
  )
}

resource "proxmox_download_file" "ubuntu_noble" {
  content_type = "iso"
  datastore_id = var.image_datastore
  node_name    = var.node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.img"

  overwrite           = false
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = var.image_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "${var.name}-cloud-init.yaml"
    data      = module.core.cloud_init_config
  }
}

resource "proxmox_virtual_environment_vm" "docker" {
  name            = var.name
  description     = var.vm_description
  tags            = ["terraform"]
  node_name       = var.node_name
  vm_id           = var.vm_id
  on_boot         = true
  stop_on_destroy = true

  agent { enabled = true }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory { dedicated = var.memory }

  disk {
    datastore_id = var.image_datastore
    file_id      = proxmox_download_file.ubuntu_noble.id
    interface    = "scsi0"
    file_format  = "raw"
    size         = var.disk_size
    discard      = "on"
  }

  network_device { bridge = "vmbr0" }

  initialization {
    datastore_id      = var.image_datastore
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
    ip_config {
      ipv4 {
        address = var.ip
        gateway = var.gateway
      }
    }
  }
}
