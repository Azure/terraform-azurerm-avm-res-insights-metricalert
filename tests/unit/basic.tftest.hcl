mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  name             = "alert-unit-basic"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit"
  scopes           = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunit"]
  enable_telemetry = false
  static_criteria = {
    transactions = {
      name        = "HighTransactionCount"
      metric_name = "Transactions"
      aggregation = "Total"
      operator    = "GreaterThan"
      threshold   = 100
    }
  }
}

# Basic deployment: a single scope and a single static criterion.
run "basic_deployment" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Insights/metricAlerts@2026-01-01"
    error_message = "The module must default to the latest stable metric alert API version."
  }
  assert {
    condition     = azapi_resource.this.name == "alert-unit-basic"
    error_message = "The alert rule name must be taken from `var.name`."
  }
  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id
    error_message = "The alert rule must be created in the supplied `parent_id`."
  }
  assert {
    condition     = azapi_resource.this.location == "global"
    error_message = "`Microsoft.Insights/metricAlerts` is a global resource type."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria["odata.type"] == "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
    error_message = "A single scope with only static criteria must use the single-resource criteria model."
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.criteria.allOf) == 1
    error_message = "Exactly one criterion must be rendered."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].criterionType == "StaticThresholdCriterion"
    error_message = "Entries in `static_criteria` must render as `StaticThresholdCriterion`."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].name == "HighTransactionCount"
    error_message = "The Azure-visible criterion name must come from `static_criteria[*].name`, not from the map key."
  }
  assert {
    condition     = azapi_resource.this.body.properties.severity == 3
    error_message = "`severity` must default to 3."
  }
  assert {
    condition     = azapi_resource.this.body.properties.enabled == true
    error_message = "`enabled` must default to true."
  }
  assert {
    condition     = azapi_resource.this.body.properties.evaluationFrequency == "PT1M" && azapi_resource.this.body.properties.windowSize == "PT5M"
    error_message = "The default evaluation frequency and window size must be PT1M and PT5M."
  }
  assert {
    condition     = azapi_resource.this.body.properties.autoMitigate == true
    error_message = "`auto_mitigate` must default to true."
  }
  assert {
    condition     = length(azapi_resource.lock) == 0
    error_message = "No lock must be created when `var.lock` is null."
  }
  assert {
    condition     = length(azapi_resource.role_assignments) == 0
    error_message = "No role assignments must be created when `var.role_assignments` is empty."
  }
  assert {
    condition     = length(modtm_telemetry.telemetry) == 0
    error_message = "Telemetry must not be collected when `enable_telemetry` is false."
  }
}

# Output correctness.
run "outputs" {
  command = apply

  assert {
    condition     = output.resource_id == azapi_resource.this.id
    error_message = "`resource_id` must expose the ARM resource ID of the alert rule."
  }
  assert {
    condition     = output.name == "alert-unit-basic"
    error_message = "`name` must expose the alert rule name."
  }
  assert {
    condition     = output.resource.id == azapi_resource.this.id && output.resource.location == "global"
    error_message = "`resource` must expose the alert rule object."
  }
}

# A disabled rule still renders `enabled = false` rather than omitting the property.
run "disabled_rule" {
  command = apply

  variables {
    enabled = false
  }

  assert {
    condition     = azapi_resource.this.body.properties.enabled == false
    error_message = "`enabled = false` must be sent to Azure."
  }
}

# `ignore_body_changes` collapses an empty list to null so the module remains
# usable on Terraform versions earlier than 1.11.
# `ignore_body_changes` is a write-only AzAPI attribute, so it is never readable
# from state. The input contract is asserted instead.
run "ignore_body_changes_default_is_empty" {
  command = apply

  assert {
    condition     = length(var.ignore_body_changes.insights_metric_alerts) == 0
    error_message = "`ignore_body_changes.insights_metric_alerts` must default to an empty list."
  }
}

run "ignore_body_changes_supplied" {
  command = apply

  variables {
    ignore_body_changes = {
      insights_metric_alerts = ["properties.description"]
    }
  }

  assert {
    condition     = one(var.ignore_body_changes.insights_metric_alerts) == "properties.description"
    error_message = "`ignore_body_changes.insights_metric_alerts` must accept body-relative dot paths."
  }
}

# `resource_types` allows consumers to pin a different API version.
run "resource_types_override" {
  command = apply

  variables {
    resource_types = {
      insights_metric_alerts = "Microsoft.Insights/metricAlerts@2018-03-01"
    }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Insights/metricAlerts@2018-03-01"
    error_message = "`resource_types.insights_metric_alerts` must override the API version."
  }
}
