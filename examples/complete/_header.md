# Complete example

This example exercises the full surface of the module: multiple static criteria with `Include` and `Exclude` dimensions, multiple action groups with webhook properties, a user-assigned managed identity, a resource lock, tags, custom properties and per-operation timeouts.

The rule is scoped to a single storage account, so the module selects the `Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria` criteria model. Azure Monitor does not support multi-resource metric alerts for `Microsoft.Storage/storageAccounts`, which is why this example does not set `target_resource_type` or `target_resource_region`.
