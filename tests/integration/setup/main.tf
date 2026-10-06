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

variable "location" {
  type        = string
  default     = "swedencentral"
  description = "The Azure region used for the supporting resources."
  nullable    = false
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "rg" {
  location  = var.location
  name      = "rg-avm-metricalert-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type      = "Microsoft.Resources/resourceGroups@2021-04-01"
}

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
      allowBlobPublicAccess = false
      allowSharedKeyAccess  = false
      minimumTlsVersion     = "TLS1_2"
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
      }
      publicNetworkAccess      = "Disabled"
      supportsHttpsTrafficOnly = true
    }
  }
}

resource "azapi_resource" "action_group" {
  location  = "Global"
  name      = "ag-avm-metricalert-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Insights/actionGroups@2023-01-01"
  body = {
    properties = {
      enabled        = true
      groupShortName = "avmma"
    }
  }
}

output "action_group_id" {
  description = "The resource ID of the supporting action group."
  value       = azapi_resource.action_group.id
}

output "location" {
  description = "The Azure region the supporting resources were created in."
  value       = var.location
}

output "name_suffix" {
  description = "The random suffix used to make the supporting resource names unique."
  value       = random_string.suffix.result
}

output "resource_group_id" {
  description = "The resource ID of the supporting resource group."
  value       = azapi_resource.rg.id
}

output "storage_account_id" {
  description = "The resource ID of the supporting storage account."
  value       = azapi_resource.storage.id
}
