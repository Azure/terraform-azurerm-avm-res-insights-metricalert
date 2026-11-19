terraform {
  required_version = ">= 1.11.0, < 2.0.0"

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
  name                   = "rg-avm-metricalert-waf-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  response_export_values = []
}

resource "azapi_resource" "storage" {
  location  = var.location
  name      = "stavmmw${random_string.suffix.result}"
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

resource "azapi_resource" "action_group" {
  location  = "Global"
  name      = "ag-avm-metricalert-waf-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Insights/actionGroups@2023-01-01"
  body = {
    properties = {
      enabled        = true
      groupShortName = "avmmawaf"
      emailReceivers = [
        {
          name                 = "operations"
          emailAddress         = var.notification_email
          useCommonAlertSchema = true
        }
      ]
    }
  }
  response_export_values = []
}

module "metric_alert" {
  source = "../../"

  name      = "alert-storage-availability-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  scopes    = [azapi_resource.storage.id]
  actions = {
    operations = {
      action_group_id = azapi_resource.action_group.id
    }
  }
  auto_mitigate        = true
  description          = "Investigate storage service errors when average availability falls below 99.9 percent over 15 minutes."
  enable_telemetry     = var.enable_telemetry
  enabled              = true
  evaluation_frequency = "PT5M"
  location             = "global"
  severity             = 2
  static_criteria = {
    availability = {
      name             = "LowAvailability"
      metric_namespace = "Microsoft.Storage/storageAccounts"
      metric_name      = "Availability"
      aggregation      = "Average"
      operator         = "LessThan"
      threshold        = 99.9
    }
  }
  tags = {
    environment = "avm-example"
    scenario    = "waf-aligned"
  }
  window_size = "PT15M"
}
