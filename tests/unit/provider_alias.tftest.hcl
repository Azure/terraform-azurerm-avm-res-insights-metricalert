mock_provider "azapi" {
  alias = "alternate"
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  name             = "alert-unit-aliased-provider"
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

# The module declares no provider configuration, so consumers may supply an
# aliased AzAPI provider. The fixture wires `azapi.alternate` into the module.
run "aliased_azapi_provider" {
  command = apply

  module {
    source = "./tests/fixtures/aliased_provider"
  }

  assert {
    condition     = output.name == "alert-unit-aliased-provider"
    error_message = "The module must be usable with an aliased AzAPI provider."
  }
  assert {
    condition     = output.resource_id != null
    error_message = "The module must produce a resource ID when driven by an aliased AzAPI provider."
  }
}
