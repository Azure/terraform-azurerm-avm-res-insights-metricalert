mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "modtm" {}

mock_provider "random" {}

mock_provider "terraform" {}

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
  assert {
    condition = (
      azapi_resource.telemetry[0].type == "Microsoft.Resources/deployments@2025-04-01" &&
      azapi_resource.telemetry[0].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000" &&
      azapi_resource.telemetry[0].location == var.location &&
      azapi_resource.telemetry[0].body.properties.mode == "Incremental" &&
      length(azapi_resource.telemetry[0].body.properties.template.resources) == 0 &&
      startswith(azapi_resource.telemetry[0].name, "${jsondecode(file("metadata.json")).telemetryIdPrefix}.")
    )
    error_message = "Telemetry must use the metadata-backed empty incremental deployment at the active subscription."
  }
  providers = {
    azapi     = azapi
    modtm     = modtm
    random    = random
    terraform = terraform
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
  assert {
    condition     = length(data.azapi_client_config.telemetry) == 0
    error_message = "Opting out must also omit the telemetry client configuration lookup."
  }
  providers = {
    azapi     = azapi
    modtm     = modtm
    random    = random
    terraform = terraform
  }
}
