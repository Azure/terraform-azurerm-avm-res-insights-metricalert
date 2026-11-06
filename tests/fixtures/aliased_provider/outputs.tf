output "name" {
  description = "The name of the metric alert rule created through an aliased AzAPI provider."
  value       = module.test.name
}

output "resource_id" {
  description = "The resource ID of the metric alert rule created through an aliased AzAPI provider."
  value       = module.test.resource_id
}
