# terraform-azurerm-avm-res-insights-metricalert

Azure Verified Module for Azure Monitor metric alert rules (`Microsoft.Insights/metricAlerts`).

The module creates and manages a single metric alert rule and its child lock and role assignments. Every Azure operation is performed through the [AzAPI provider](https://registry.terraform.io/providers/Azure/azapi/latest/docs); the module does not use, and does not require, the AzureRM provider.

## API version

The module targets `Microsoft.Insights/metricAlerts@2026-01-01`, the latest **stable** ARM API version for this resource type. No preview API version is used. Consumers can pin a different API version through `var.resource_types` without forking the module.

The Terraform inputs are modelled directly on the ARM resource schema rather than on the AzureRM resource, so property names, enums and cardinalities follow the [Azure Monitor metric alerts REST API](https://learn.microsoft.com/rest/api/monitor/metric-alerts).

## Criteria models

ARM models the `criteria` property as a discriminated object keyed on `odata.type`. The module derives the discriminator from the inputs instead of asking the consumer to set it:

| Inputs | `odata.type` |
| --- | --- |
| `webtest_criteria` is set | `Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria` |
| any `dynamic_criteria`, more than one scope, or `target_resource_type` is set | `Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria` |
| otherwise | `Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria` |

`static_criteria` entries render as `StaticThresholdCriterion` and `dynamic_criteria` entries render as `DynamicThresholdCriterion`. Both maps can be used together; the module concatenates them into a single `allOf` array in lexical map-key order so that plans stay stable.

`webtest_criteria` cannot be combined with `static_criteria` or `dynamic_criteria`, and at least one criterion must be supplied. Both rules are enforced by resource preconditions.

### Map keys versus Azure names

`actions`, `static_criteria`, `dynamic_criteria` and `dimensions` are maps keyed by an arbitrary, stable string. The key is used only for Terraform identity and plan stability. The Azure-visible name always comes from the `name` attribute inside the object, which lets you rename a criterion in Azure without recreating unrelated entries, and vice versa.

## Managed identities

ARM restricts `identity.type` on this resource type to `SystemAssigned`, `UserAssigned` or `None`. The combined `SystemAssigned, UserAssigned` value is rejected by the service, so `var.managed_identities` validates that `system_assigned` and `user_assigned_resource_ids` are not used together.

## Example

```hcl
module "metric_alert" {
  source  = "Azure/avm-res-insights-metricalert/azurerm"
  version = "~> 0.1"

  name      = "alert-storage-transactions"
  parent_id = azapi_resource.rg.id
  scopes    = [azapi_resource.storage.id]

  severity = 2
  static_criteria = {
    transactions = {
      name        = "HighTransactionCount"
      metric_name = "Transactions"
      aggregation = "Total"
      operator    = "GreaterThan"
      threshold   = 1000
      dimensions = {
        api = {
          name     = "ApiName"
          operator = "Include"
          values   = ["*"]
        }
      }
    }
  }

  actions = {
    ops = {
      action_group_id = azapi_resource.action_group.id
    }
  }
}
```

## Import

Metric alert rules are imported with their ARM resource ID:

```hcl
import {
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.Insights/metricAlerts/alert-storage-transactions"
  to = module.metric_alert.azapi_resource.this
}
```

## Drift control

`var.ignore_body_changes.insights_metric_alerts` accepts body-relative dot paths (for example `properties.description`) that AzAPI should ignore when it compares the configured body with the remote state. Use it when another system owns part of the rule.

## Interfaces

| Interface | Status | Rationale |
| --- | --- | --- |
| Tags | Included | `Microsoft.Insights/metricAlerts` supports ARM tags. |
| Resource locks | Included | The rule is a lockable ARM resource. |
| Role assignments | Included | The rule is a valid RBAC scope. |
| Managed identities | Included | The ARM schema exposes `identity`, with the restriction described above. |
| Telemetry | Included | Required by the AVM specification. |
| `resource_types`, `retry`, `timeouts`, `ignore_body_changes` | Included | Required AzAPI control interfaces. |
| Diagnostic settings | Excluded | The resource type exposes no diagnostic log or metric categories. |
| Customer managed keys | Excluded | The ARM schema exposes no encryption properties. |
| Private endpoints | Excluded | The ARM schema exposes no `privateEndpointConnections`; the resource is a global control-plane object with no data-plane endpoint. |

## Known gaps

- PromQL criteria (`Microsoft.Azure.Monitor.PromQLCriteria`) are not modelled.
- `properties.resolveConfiguration` is not modelled.
