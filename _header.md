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

`static_criteria` entries render as `StaticThresholdCriterion` and `dynamic_criteria` entries render as `DynamicThresholdCriterion`. The module concatenates both maps into a single `allOf` array in lexical map-key order so that plans stay stable.

`webtest_criteria` cannot be combined with `static_criteria` or `dynamic_criteria`, and at least one criterion must be supplied. Both rules are enforced by resource preconditions.

### Service constraints beyond the ARM schema

Several Azure Monitor rules are not expressible in the ARM schema. Each of the following was confirmed against the live service during end-to-end testing. The module enforces the first with a precondition; the rest depend on the monitored resource type or the criteria kind and are left to the consumer:

- **A dynamic alert supports exactly one criterion.** Supplying more than one `dynamic_criteria` entry, or mixing `dynamic_criteria` with `static_criteria`, is rejected with `Maximum 1 criteria is allowed when using dynamic alert`. This is enforced by a resource precondition.
- **Dimensions cannot be used on a rule with multiple criteria.** A rule with more than one entry across `static_criteria` and `dynamic_criteria` is rejected with `When the alert rule contains multiple criteria, the use of dimensions is limited to one value per dimension within each criterion`, even when every dimension carries a single concrete value. Use one criterion when you need dimensions.
- **Multi-resource alerts are only supported for certain resource types.** More than one entry in `scopes` requires that the monitored resource type supports multi-resource metric alerts. `Microsoft.Storage/storageAccounts` is rejected with `Alerts are currently not supported with multi resource level`. The supported list is a service-side property that changes over time, so the module does not validate it.
- **`custom_properties` is only accepted on `Query` kind rules.** Setting it on a metric criteria rule is rejected with `CustomProperties are currently supported for 'Query' kind Metric Alert rule only`.
- **Managed identities are only accepted on query criteria.** Setting an `identity` block on a metric criteria rule is rejected with `Managed Identity is not supported for non-query criterion`. Because this module implements the metric and web test criteria models, the identity block is unusable on every configuration the module can produce, so the managed identities interface is not exposed. It becomes applicable only if PromQL/query criteria are added.

### Map keys versus Azure names

`actions`, `static_criteria`, `dynamic_criteria` and `dimensions` are maps keyed by an arbitrary, stable string. The key is used only for Terraform identity and plan stability. The Azure-visible name always comes from the `name` attribute inside the object, which lets you rename a criterion in Azure without recreating unrelated entries, and vice versa.

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

## Deleting a locked rule

When `var.lock` is set, a single `terraform destroy` can fail with `ScopeLocked` even though Terraform correctly deletes the lock before the rule. Azure enforces management locks through a cache that is only eventually consistent, so the delete that immediately follows the lock removal can still be rejected:

```text
The scope '/subscriptions/.../metricAlerts/<name>' cannot perform delete operation
because following scope(s) are locked. Please remove the lock and try again.
```

Re-running `terraform destroy` succeeds once the lock removal has propagated. This is service-side behaviour rather than a module defect, so the module does not add a delay or a destroy-time retry to mask it.

## Interfaces

| Interface | Status | Rationale |
| --- | --- | --- |
| Tags | Included | `Microsoft.Insights/metricAlerts` supports ARM tags. |
| Resource locks | Included | The rule is a lockable ARM resource. |
| Role assignments | Included | The rule is a valid RBAC scope. |
| Telemetry | Included | Required by the AVM specification. |
| `resource_types`, `retry`, `timeouts`, `ignore_body_changes` | Included | Required AzAPI control interfaces. |
| Diagnostic settings | Excluded | The resource type exposes no diagnostic log or metric categories. |
| Managed identities | Excluded | The ARM schema exposes `identity`, but Azure Monitor rejects it for the metric and web test criteria this module implements, so the interface would be a no-op. See the service constraints above. |
| Customer managed keys | Excluded | The ARM schema exposes no encryption properties. |
| Private endpoints | Excluded | The ARM schema exposes no `privateEndpointConnections`; the resource is a global control-plane object with no data-plane endpoint. |

## Known gaps

- PromQL criteria (`Microsoft.Azure.Monitor.PromQLCriteria`) are not modelled.
- `properties.resolveConfiguration` is not modelled.
