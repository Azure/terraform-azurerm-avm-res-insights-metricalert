# Complete example

This example exercises the full surface of the module: multiple static criteria with `Include` and `Exclude` dimensions, multiple action groups with webhook properties, a multi-resource scope, a user-assigned managed identity, a resource lock, tags, custom properties and per-operation timeouts.

Because more than one resource is supplied in `scopes`, `target_resource_type` and `target_resource_region` are required and the module selects the `Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria` criteria model.
