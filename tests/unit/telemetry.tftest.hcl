mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  name      = "alert-unit-telemetry"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit"
  scopes    = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunit"]
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

run "telemetry_enabled" {
  command = apply

  variables {
    enable_telemetry = true
  }

  assert {
    condition     = length(azapi_resource.telemetry) == 1
    error_message = "Telemetry must be collected when `enable_telemetry` is true."
  }
  assert {
    condition     = length(terraform_data.telemetry) == 1
    error_message = "A telemetry correlation UUID must be generated when telemetry is enabled."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "telemetry_disabled" {
  command = apply

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(azapi_resource.telemetry) == 0
    error_message = "Telemetry must not be collected when `enable_telemetry` is false."
  }
  assert {
    condition     = length(terraform_data.telemetry) == 0
    error_message = "No telemetry correlation UUID must be generated when telemetry is disabled."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
