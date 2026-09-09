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
  name                   = "rg-avm-metricalert-complete-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  response_export_values = []
}

# Azure Monitor does not support multi-resource metric alerts for
# `Microsoft.Storage/storageAccounts`, so this example scopes the rule to a single
# storage account and uses the single-resource criteria model.
resource "azapi_resource" "storage" {
  location  = var.location
  name      = "stavmmc${random_string.suffix.result}"
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

# Two action groups so that the example exercises multiple `actions` entries.
resource "azapi_resource" "action_group" {
  for_each = toset(["ops", "oncall"])

  location  = "Global"
  name      = "ag-avm-${each.key}-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Insights/actionGroups@2023-01-01"
  body = {
    properties = {
      enabled        = true
      groupShortName = substr(each.key, 0, 12)
      emailReceivers = [
        {
          name                 = "${each.key}-mailbox"
          emailAddress         = "${each.key}@contoso.example"
          useCommonAlertSchema = true
        }
      ]
    }
  }
  response_export_values = []
}

# This is the module call.
module "metric_alert" {
  source = "../../"

  name      = "alert-storage-complete-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  scopes    = [azapi_resource.storage.id]
  actions = {
    ops = {
      action_group_id = azapi_resource.action_group["ops"].id
      webhook_properties = {
        runbook = "storage-availability"
      }
    }
    oncall = {
      action_group_id = azapi_resource.action_group["oncall"].id
    }
  }
  auto_mitigate        = true
  description          = "Alerts when storage transactions or availability breach the configured static thresholds."
  enable_telemetry     = var.enable_telemetry # see variables.tf
  enabled              = true
  evaluation_frequency = "PT5M"
  lock = {
    kind  = "CanNotDelete"
    notes = "Managed by the AVM metric alert example."
  }
  severity = 2
  static_criteria = {
    # Azure Monitor does not accept dimensions on a rule that carries more than
    # one criterion, so this example uses a single criterion and exercises both
    # the `Include` and `Exclude` dimension operators on it.
    transactions = {
      name        = "HighTransactionCount"
      metric_name = "Transactions"
      aggregation = "Total"
      operator    = "GreaterThan"
      threshold   = 1000
      dimensions = {
        api_name = {
          name     = "ApiName"
          operator = "Include"
          values   = ["*"]
        }
        geo_type = {
          name     = "GeoType"
          operator = "Exclude"
          values   = ["Secondary"]
        }
      }
    }
  }
  tags = {
    environment = "avm-example"
    scenario    = "complete"
  }
  timeouts = {
    create = "30m"
    delete = "30m"
  }
  window_size = "PT15M"
}
