output "ip" {
  value       = local.vm_ip
  description = "VM static IP (without prefix length)"
}

output "vm_id" {
  value       = proxmox_virtual_environment_vm.docker.id
  description = "Proxmox VM ID"
}
