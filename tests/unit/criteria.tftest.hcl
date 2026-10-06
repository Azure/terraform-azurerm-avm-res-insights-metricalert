mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  name             = "alert-unit-criteria"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit"
  scopes           = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunit"]
  enable_telemetry = false
}

# Dynamic thresholds force the multiple-resource criteria model and render the
# required `failingPeriods` object.
run "dynamic_thresholds" {
  command = apply

  variables {
    dynamic_criteria = {
      transactions = {
        name                         = "UnusualTransactionVolume"
        metric_name                  = "Transactions"
        aggregation                  = "Total"
        operator                     = "GreaterOrLessThan"
        alert_sensitivity            = "Medium"
        number_of_evaluation_periods = 4
        min_failing_periods_to_alert = 3
      }
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.criteria["odata.type"] == "Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria"
    error_message = "Dynamic thresholds must select the multiple-resource criteria model."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].criterionType == "DynamicThresholdCriterion"
    error_message = "Entries in `dynamic_criteria` must render as `DynamicThresholdCriterion`."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].alertSensitivity == "Medium"
    error_message = "`alert_sensitivity` must be rendered as `alertSensitivity`."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].failingPeriods.numberOfEvaluationPeriods == 4
    error_message = "`number_of_evaluation_periods` must be rendered as `failingPeriods.numberOfEvaluationPeriods`."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].failingPeriods.minFailingPeriodsToAlert == 3
    error_message = "`min_failing_periods_to_alert` must be rendered as `failingPeriods.minFailingPeriodsToAlert`."
  }
}

# Azure Monitor rejects a dynamic alert that carries more than one criterion, so
# mixing static and dynamic criteria must fail the module precondition.
run "static_and_dynamic_criteria_cannot_be_combined" {
  command = plan

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
      }
    }
    dynamic_criteria = {
      ingress = {
        name              = "UnusualIngress"
        metric_name       = "Ingress"
        aggregation       = "Total"
        operator          = "GreaterThan"
        alert_sensitivity = "Low"
      }
    }
  }

  expect_failures = [azapi_resource.this]
}

# More than one dynamic criterion is rejected by the same service constraint.
run "multiple_dynamic_criteria_are_rejected" {
  command = plan

  variables {
    dynamic_criteria = {
      ingress = {
        name              = "UnusualIngress"
        metric_name       = "Ingress"
        aggregation       = "Total"
        operator          = "GreaterThan"
        alert_sensitivity = "Low"
      }
      egress = {
        name              = "UnusualEgress"
        metric_name       = "Egress"
        aggregation       = "Total"
        operator          = "GreaterThan"
        alert_sensitivity = "Low"
      }
    }
  }

  expect_failures = [azapi_resource.this]
}

# Dimension include and exclude filters, with the Azure-visible dimension name
# taken from the object rather than the map key.
run "dimension_include_and_exclude" {
  command = apply

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
        dimensions = {
          a_api = {
            name     = "ApiName"
            operator = "Include"
            values   = ["*"]
          }
          b_geo = {
            name     = "GeoType"
            operator = "Exclude"
            values   = ["Secondary"]
          }
        }
      }
    }
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.criteria.allOf[0].dimensions) == 2
    error_message = "Both dimensions must be rendered."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].dimensions[0].name == "ApiName"
    error_message = "The Azure-visible dimension name must come from `dimensions[*].name`, not from the map key."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].dimensions[0].operator == "Include"
    error_message = "The `Include` dimension operator must be preserved."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.allOf[0].dimensions[1].operator == "Exclude"
    error_message = "The `Exclude` dimension operator must be preserved."
  }
}

# Multiple scopes require the target resource type and region and select the
# multiple-resource criteria model.
run "multiple_scopes" {
  command = apply

  variables {
    scopes = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunita",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunitb",
    ]
    target_resource_type   = "Microsoft.Storage/storageAccounts"
    target_resource_region = "swedencentral"
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

  assert {
    condition     = length(azapi_resource.this.body.properties.scopes) == 2
    error_message = "Both scopes must be sent to Azure."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria["odata.type"] == "Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria"
    error_message = "Multiple scopes must select the multiple-resource criteria model."
  }
  assert {
    condition     = azapi_resource.this.body.properties.targetResourceType == "Microsoft.Storage/storageAccounts"
    error_message = "`target_resource_type` must be sent to Azure."
  }
  assert {
    condition     = azapi_resource.this.body.properties.targetResourceRegion == "swedencentral"
    error_message = "`target_resource_region` must be sent to Azure."
  }
}

# Web test availability criteria are a single ARM object, so `allOf` must be absent.
run "webtest_criteria" {
  command = apply

  variables {
    scopes = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/webtests/wt",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/components/appi",
    ]
    target_resource_type   = "Microsoft.Insights/webtests"
    target_resource_region = "swedencentral"
    webtest_criteria = {
      web_test_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/webtests/wt"
      component_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/components/appi"
      failed_location_count = 2
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.criteria["odata.type"] == "Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria"
    error_message = "`webtest_criteria` must select the web test availability criteria model."
  }
  assert {
    condition     = azapi_resource.this.body.properties.criteria.failedLocationCount == 2
    error_message = "`failed_location_count` must be rendered as `failedLocationCount`."
  }
  assert {
    condition     = !can(azapi_resource.this.body.properties.criteria.allOf)
    error_message = "`allOf` must be absent for the web test availability criteria model."
  }
}

# Multiple action groups, with webhook properties on one of them.
run "multiple_action_groups" {
  command = apply

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
      }
    }
    actions = {
      a_ops = {
        action_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/actionGroups/ag-ops"
        webhook_properties = {
          runbook = "storage-availability"
        }
      }
      b_oncall = {
        action_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/actionGroups/ag-oncall"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.this.body.properties.actions) == 2
    error_message = "Both action groups must be rendered."
  }
  assert {
    condition     = azapi_resource.this.body.properties.actions[0].actionGroupId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/actionGroups/ag-ops"
    error_message = "Action group entries must be rendered in lexical map-key order for plan stability."
  }
  assert {
    condition     = azapi_resource.this.body.properties.actions[0].webHookProperties.runbook == "storage-availability"
    error_message = "`webhook_properties` must be rendered as `webHookProperties`."
  }
}
