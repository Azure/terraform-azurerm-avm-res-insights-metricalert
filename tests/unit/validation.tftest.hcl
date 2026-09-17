mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  name             = "alert-unit-validation"
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

run "invalid_severity" {
  command = plan

  variables {
    severity = 5
  }

  expect_failures = [var.severity]
}

run "empty_scopes" {
  command = plan

  variables {
    scopes = []
  }

  expect_failures = [var.scopes]
}

run "invalid_scope_id" {
  command = plan

  variables {
    scopes = ["not-a-resource-id"]
  }

  expect_failures = [var.scopes]
}

run "invalid_static_aggregation" {
  command = plan

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Percentile"
        operator    = "GreaterThan"
        threshold   = 100
      }
    }
  }

  expect_failures = [var.static_criteria]
}

run "invalid_static_operator" {
  command = plan

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterOrLessThan"
        threshold   = 100
      }
    }
  }

  expect_failures = [var.static_criteria]
}

run "invalid_dynamic_operator" {
  command = plan

  variables {
    static_criteria = {}
    dynamic_criteria = {
      transactions = {
        name              = "UnusualTransactionVolume"
        metric_name       = "Transactions"
        aggregation       = "Total"
        operator          = "GreaterThanOrEqual"
        alert_sensitivity = "Medium"
      }
    }
  }

  expect_failures = [var.dynamic_criteria]
}

run "invalid_dynamic_failing_periods" {
  command = plan

  variables {
    static_criteria = {}
    dynamic_criteria = {
      transactions = {
        name                         = "UnusualTransactionVolume"
        metric_name                  = "Transactions"
        aggregation                  = "Total"
        operator                     = "GreaterThan"
        alert_sensitivity            = "Medium"
        number_of_evaluation_periods = 4
        min_failing_periods_to_alert = 5
      }
    }
  }

  expect_failures = [var.dynamic_criteria]
}

run "fractional_dynamic_failing_periods" {
  command = plan

  variables {
    static_criteria = {}
    dynamic_criteria = {
      transactions = {
        name                         = "UnusualTransactionVolume"
        metric_name                  = "Transactions"
        aggregation                  = "Total"
        operator                     = "GreaterThan"
        alert_sensitivity            = "Medium"
        number_of_evaluation_periods = 4.5
        min_failing_periods_to_alert = 2
      }
    }
  }

  expect_failures = [var.dynamic_criteria]
}

run "invalid_dimension_operator" {
  command = plan

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
        dimensions = {
          api = {
            name     = "ApiName"
            operator = "StartsWith"
            values   = ["*"]
          }
        }
      }
    }
  }

  expect_failures = [var.static_criteria]
}

run "missing_dimension_values" {
  command = plan

  variables {
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
        dimensions = {
          api = {
            name     = "ApiName"
            operator = "Include"
            values   = []
          }
        }
      }
    }
  }

  expect_failures = [var.static_criteria]
}

run "invalid_evaluation_frequency" {
  command = plan

  variables {
    evaluation_frequency = "PT2M"
  }

  expect_failures = [var.evaluation_frequency]
}

run "window_size_smaller_than_evaluation_frequency" {
  command = plan

  variables {
    evaluation_frequency = "PT15M"
    window_size          = "PT5M"
  }

  expect_failures = [var.window_size]
}

run "invalid_action_group_id" {
  command = plan

  variables {
    actions = {
      ops = {
        action_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunit"
      }
    }
  }

  expect_failures = [var.actions]
}

run "empty_action_group_id" {
  command = plan

  variables {
    actions = {
      ops = {
        action_group_id = ""
      }
    }
  }

  expect_failures = [var.actions]
}

run "invalid_target_resource_type" {
  command = plan

  variables {
    target_resource_type = "Microsoft.Storage"
  }

  expect_failures = [var.target_resource_type]
}

run "invalid_location" {
  command = plan

  variables {
    location = "swedencentral"
  }

  expect_failures = [var.location]
}

run "no_criteria_supplied" {
  command = plan

  variables {
    static_criteria = {}
  }

  expect_failures = [azapi_resource.this]
}

run "webtest_criteria_cannot_be_combined_with_metric_criteria" {
  command = plan

  variables {
    target_resource_type   = "Microsoft.Insights/webtests"
    target_resource_region = "swedencentral"
    webtest_criteria = {
      web_test_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/webtests/wt"
      component_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/components/appi"
      failed_location_count = 2
    }
  }

  expect_failures = [azapi_resource.this]
}

run "fractional_failed_location_count" {
  command = plan

  variables {
    static_criteria        = {}
    target_resource_type   = "Microsoft.Insights/webtests"
    target_resource_region = "swedencentral"
    webtest_criteria = {
      web_test_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/webtests/wt"
      component_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/components/appi"
      failed_location_count = 1.5
    }
  }

  expect_failures = [var.webtest_criteria]
}

run "duplicate_criterion_names" {
  command = plan

  variables {
    static_criteria = {
      first = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
      }
      second = {
        name        = "HighTransactionCount"
        metric_name = "Ingress"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
      }
    }
  }

  expect_failures = [azapi_resource.this]
}

run "multiple_scopes_require_target_resource_type_and_region" {
  command = plan

  variables {
    scopes = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunita",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunitb",
    ]
  }

  expect_failures = [azapi_resource.this]
}
