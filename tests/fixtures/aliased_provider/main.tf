terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azapi = {
      source                = "Azure/azapi"
      version               = "~> 2.12"
      configuration_aliases = [azapi.alternate]
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# This fixture exists purely to prove that the module can be consumed with an
# aliased AzAPI provider. The module itself declares no provider configuration.
module "test" {
  source = "../../../"

  providers = {
    azapi = azapi.alternate
  }

  name      = "alert-unit-aliased-provider"
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
  enable_telemetry = false
}

output "name" {
  description = "The name of the metric alert rule created through an aliased AzAPI provider."
  value       = module.test.name
}

output "resource_id" {
  description = "The resource ID of the metric alert rule created through an aliased AzAPI provider."
  value       = module.test.resource_id
}
