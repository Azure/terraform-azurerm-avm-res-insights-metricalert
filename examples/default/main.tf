terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azapi" {}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "rg" {
  location               = var.location
  name                   = "rg-avm-metricalert-default-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  response_export_values = []
}

# A monitored resource is required so that the alert rule has a scope to
# evaluate. Any resource that emits metrics works; a storage account is used
# here because it is inexpensive and emits metrics immediately.
resource "azapi_resource" "storage" {
  location  = var.location
  name      = "stavmma${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_ZRS"
    }
    properties = {
      allowBlobPublicAccess    = false
      allowSharedKeyAccess     = false
      minimumTlsVersion        = "TLS1_2"
      publicNetworkAccess      = "Disabled"
      supportsHttpsTrafficOnly = true
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
      }
    }
  }
  response_export_values = []
}

# This is the module call.
module "metric_alert" {
  source = "../../"

  name             = "alert-storage-transactions-${random_string.suffix.result}"
  parent_id        = azapi_resource.rg.id
  scopes           = [azapi_resource.storage.id]
  enable_telemetry = var.enable_telemetry # see variables.tf
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
