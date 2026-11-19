mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "random" {}

variables {
  location = "westeurope"
}

run "default_keeps_global_alert_location" {
  command = plan

  module {
    source = "./examples/default"
  }

  assert {
    condition     = module.metric_alert.resource.location == "global" && azapi_resource.rg.location == var.location
    error_message = "The alert must remain global while supporting resources use the example region."
  }
}

run "waf_aligned_routes_availability_alert" {
  command = apply

  module {
    source = "./examples/waf-aligned"
  }

  variables {
    enable_telemetry   = false
    notification_email = "alerts@example.com"
  }

  override_resource {
    target = azapi_resource.rg
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/waf-example"
    }
  }

  override_resource {
    target = azapi_resource.storage
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/waf-example/providers/Microsoft.Storage/storageAccounts/wafexample"
    }
  }

  override_resource {
    target = azapi_resource.action_group
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/waf-example/providers/Microsoft.Insights/actionGroups/operations"
    }
  }

  assert {
    condition = (
      module.metric_alert.resource.location == "global" &&
      azapi_resource.rg.location == var.location &&
      azapi_resource.storage.location == var.location &&
      length(module.metric_alert.resource.body.properties.scopes) == 1 &&
      module.metric_alert.resource.body.properties.scopes[0] == azapi_resource.storage.id &&
      module.metric_alert.resource.body.properties.enabled &&
      module.metric_alert.resource.body.properties.autoMitigate &&
      module.metric_alert.resource.body.properties.criteria.allOf[0].metricName == "Availability" &&
      module.metric_alert.resource.body.properties.criteria.allOf[0].operator == "LessThan"
    )
    error_message = "The WAF example must monitor its regional storage account with an enabled, stateful global availability alert."
  }

  assert {
    condition = (
      module.metric_alert.resource.body.properties.actions[0].actionGroupId == azapi_resource.action_group.id &&
      azapi_resource.action_group.body.properties.enabled &&
      azapi_resource.action_group.body.properties.emailReceivers[0].emailAddress == var.notification_email &&
      azapi_resource.action_group.body.properties.emailReceivers[0].useCommonAlertSchema
    )
    error_message = "The WAF example must route alerts to the configured operations mailbox through an enabled action group using the common alert schema."
  }

  assert {
    condition = (
      azapi_resource.storage.body.sku.name == "Standard_ZRS" &&
      !azapi_resource.storage.body.properties.allowBlobPublicAccess &&
      !azapi_resource.storage.body.properties.allowSharedKeyAccess &&
      azapi_resource.storage.body.properties.publicNetworkAccess == "Disabled" &&
      azapi_resource.storage.body.properties.networkAcls.defaultAction == "Deny" &&
      azapi_resource.storage.body.properties.supportsHttpsTrafficOnly &&
      azapi_resource.storage.body.properties.minimumTlsVersion == "TLS1_2"
    )
    error_message = "The monitored storage account must retain zone redundancy and its network, authorization, and transport protections."
  }
}

run "complete_keeps_global_alert_location" {
  command = plan

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = module.metric_alert.resource.location == "global" && azapi_resource.rg.location == var.location
    error_message = "The alert must remain global while supporting resources use the example region."
  }

}

run "dynamic_threshold_keeps_global_alert_location" {
  command = plan

  module {
    source = "./examples/dynamic_threshold"
  }

  assert {
    condition     = module.metric_alert.resource.location == "global" && azapi_resource.rg.location == var.location
    error_message = "The alert must remain global while supporting resources use the example region."
  }
}

run "webtest_keeps_global_alert_location" {
  command = plan

  module {
    source = "./examples/ignore_example_for_e2e"
  }

  assert {
    condition     = module.metric_alert.resource.location == "global" && azapi_resource.rg.location == var.location
    error_message = "The alert must remain global while supporting resources use the example region."
  }
}
