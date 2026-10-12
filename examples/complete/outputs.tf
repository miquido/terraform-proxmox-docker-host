output "ip" {
  description = "IP of the VM; the A records for <domain> and *.<domain> point to it."
  value       = module.docker_host.ip
}

output "nameservers" {
  description = "Delegate the domain to these (NS records in the parent zone) so the wildcard certificate can be issued."
  value       = aws_route53_zone.main.name_servers
}

output "registry_url" {
  value = var.enable_registry ? "registry.${var.domain}" : null
}

output "registry_username" {
  value = var.enable_registry ? local.registry_username : null
}

output "registry_password" {
  value     = var.enable_registry ? random_password.registry[0].result : null
  sensitive = true
}

output "walg_backup_bucket" {
  description = "Bucket the host role may use for WAL-G; set WALG_S3_PREFIX of the compose project to s3://<bucket>/walg/<project>."
  value       = aws_s3_bucket.walg.id
}
