output "status_page_url" {
  description = "Public status page. Share this with the class."
  value       = azurerm_storage_account.main.primary_web_endpoint
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "storage_account" {
  value = azurerm_storage_account.main.name
}

output "report_containers" {
  value = [for c in azurerm_storage_container.reports : c.name]
}

output "change_ref" {
  value = var.icr_id
}
