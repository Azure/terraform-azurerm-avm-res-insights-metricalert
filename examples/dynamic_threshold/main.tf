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
  name                   = "rg-avm-metricalert-dynamic-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  response_export_values = []
}

resource "azapi_resource" "storage" {
  location  = var.location
  name      = "stavmmd${random_string.suffix.result}"
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
# Supplying `dynamic_criteria` makes the module select the
# `Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria` model, which is
# the only criteria model that supports machine-learned dynamic thresholds.
module "metric_alert" {
  source = "../../"

  name        = "alert-storage-dynamic-${random_string.suffix.result}"
  parent_id   = azapi_resource.rg.id
  scopes      = [azapi_resource.storage.id]
  description = "Alerts when storage transaction volume deviates from its learned baseline."
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
    ingress = {
      name                         = "UnusualIngress"
      metric_name                  = "Ingress"
      aggregation                  = "Total"
      operator                     = "GreaterThan"
      alert_sensitivity            = "Low"
      number_of_evaluation_periods = 6
      min_failing_periods_to_alert = 2
      dimensions = {
        api_name = {
          name     = "ApiName"
          operator = "Include"
          values   = ["*"]
        }
      }
    }
  }
  enable_telemetry     = var.enable_telemetry # see variables.tf
  evaluation_frequency = "PT5M"
  severity             = 3
  window_size          = "PT15M"
}
