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

# Two monitored storage accounts so that the alert rule uses the multi-resource
# criteria model, which requires `target_resource_type` and `target_resource_region`.
resource "azapi_resource" "storage" {
  for_each = toset(["a", "b"])

  location  = var.location
  name      = "stavmmc${each.key}${random_string.suffix.result}"
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

resource "azapi_resource" "user_assigned_identity" {
  location               = var.location
  name                   = "uai-avm-metricalert-${random_string.suffix.result}"
  parent_id              = azapi_resource.rg.id
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  response_export_values = []
}

# This is the module call.
module "metric_alert" {
  source = "../../"

  name      = "alert-storage-complete-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  scopes    = [for s in azapi_resource.storage : s.id]
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
  auto_mitigate = true
  custom_properties = {
    owner   = "platform-team"
    service = "storage"
  }
  description          = "Alerts when storage transactions or availability breach the configured static thresholds."
  enable_telemetry     = var.enable_telemetry # see variables.tf
  enabled              = true
  evaluation_frequency = "PT5M"
  lock = {
    kind  = "CanNotDelete"
    notes = "Managed by the AVM metric alert example."
  }
  managed_identities = {
    user_assigned_resource_ids = [azapi_resource.user_assigned_identity.id]
  }
  severity = 2
  static_criteria = {
    # Dimensions with the `Include` operator narrow the criterion to specific
    # dimension values.
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
      }
    }
    # Dimensions with the `Exclude` operator drop specific dimension values.
    availability = {
      name        = "LowAvailability"
      metric_name = "Availability"
      aggregation = "Average"
      operator    = "LessThan"
      threshold   = 99.9
      dimensions = {
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
  target_resource_region = var.location
  target_resource_type   = "Microsoft.Storage/storageAccounts"
  timeouts = {
    create = "30m"
    delete = "30m"
  }
  window_size = "PT15M"
}
