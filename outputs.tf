output "name" {
  description = "The name of the metric alert rule."
  value       = azapi_resource.this.name
}

output "resource" {
  description = <<DESCRIPTION
The metric alert rule. The value is an object with the following attributes:

- `id` - The fully-qualified ARM resource ID of the metric alert rule.
- `name` - The name of the metric alert rule.
- `location` - The Azure region of the metric alert rule. Always `global`.
- `tags` - The tags applied to the metric alert rule.
- `body` - The request body submitted to the Azure Monitor API.
DESCRIPTION
  value = {
    id       = azapi_resource.this.id
    name     = azapi_resource.this.name
    location = azapi_resource.this.location
    tags     = azapi_resource.this.tags
    body     = azapi_resource.this.body
  }
}

output "resource_id" {
  description = "The fully-qualified ARM resource ID of the metric alert rule."
  value       = azapi_resource.this.id
}
