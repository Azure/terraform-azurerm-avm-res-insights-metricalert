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
  name                   = "rg-avm-metricalert-webtest-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2021-04-01"
  response_export_values = []
}

resource "azapi_resource" "workspace" {
  location  = var.location
  name      = "log-avm-metricalert-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  body = {
    properties = {
      retentionInDays = 30
      sku = {
        name = "PerGB2018"
      }
    }
  }
  response_export_values = []
}

resource "azapi_resource" "component" {
  location  = var.location
  name      = "appi-avm-metricalert-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Insights/components@2020-02-02"
  body = {
    kind = "web"
    properties = {
      Application_Type    = "web"
      Flow_Type           = "Bluefield"
      Request_Source      = "rest"
      WorkspaceResourceId = azapi_resource.workspace.id
    }
  }
  response_export_values = []
}

resource "azapi_resource" "webtest" {
  location  = var.location
  name      = "webtest-avm-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Insights/webtests@2022-06-15"
  body = {
    kind = "standard"
    properties = {
      Enabled            = true
      Frequency          = 300
      Kind               = "standard"
      Locations          = [{ Id = "emea-nl-ams-azr" }, { Id = "emea-se-sto-edge" }]
      Name               = "webtest-avm-${random_string.suffix.result}"
      RetryEnabled       = true
      SyntheticMonitorId = "webtest-avm-${random_string.suffix.result}"
      Timeout            = 30
      Request = {
        RequestUrl = "https://learn.microsoft.com/azure/azure-monitor/"
        HttpVerb   = "GET"
      }
      ValidationRules = {
        ExpectedHttpStatusCode        = 200
        SSLCheck                      = true
        SSLCertRemainingLifetimeCheck = 7
      }
    }
  }
  response_export_values = []
  tags = {
    "hidden-link:${azapi_resource.component.id}" = "Resource"
  }
}

# This is the module call.
# `webtest_criteria` selects the
# `Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria` model, which the
# Azure Monitor API represents as a single criterion object rather than an
# `allOf` list. It therefore cannot be combined with `static_criteria` or
# `dynamic_criteria`.
module "metric_alert" {
  source = "../../"

  name      = "alert-webtest-${random_string.suffix.result}"
  parent_id = azapi_resource.rg.id
  scopes = [
    azapi_resource.webtest.id,
    azapi_resource.component.id,
  ]
  description            = "Alerts when the web test fails from more than one location."
  enable_telemetry       = var.enable_telemetry # see variables.tf
  evaluation_frequency   = "PT1M"
  severity               = 1
  target_resource_region = var.location
  target_resource_type   = "Microsoft.Insights/webtests"
  webtest_criteria = {
    web_test_id           = azapi_resource.webtest.id
    component_id          = azapi_resource.component.id
    failed_location_count = 2
  }
  window_size = "PT5M"
}
