mock_provider "azapi" {}
mock_provider "modtm" {}
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
    condition     = length(modtm_telemetry.telemetry) == 1
    error_message = "Telemetry must be collected when `enable_telemetry` is true."
  }
  assert {
    condition     = length(random_uuid.telemetry) == 1
    error_message = "A telemetry correlation UUID must be generated when telemetry is enabled."
  }
}

run "telemetry_disabled" {
  command = apply

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 0
    error_message = "Telemetry must not be collected when `enable_telemetry` is false."
  }
  assert {
    condition     = length(random_uuid.telemetry) == 0
    error_message = "No telemetry correlation UUID must be generated when telemetry is disabled."
  }
}
