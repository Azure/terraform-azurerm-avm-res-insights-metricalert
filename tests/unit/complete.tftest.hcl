mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "terraform" {}

# The AVM interfaces module looks role definitions up by name. This module under
# test always supplies fully qualified role definition IDs, so the lookup result
# is deliberately overridden with an empty result set.
override_data {
  target = module.avm_interfaces.data.azapi_resource_list.role_definitions[0]
  values = {
    output = {
      results = []
    }
  }
}

# The lock and role assignment resources parse `azapi_resource.this.id` as an ARM
# resource ID, so the mocked ID has to be a well formed one.
override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/metricAlerts/alert-unit-complete"
  }
}

variables {
  name      = "alert-unit-complete"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit"
  scopes = [
    "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunita",
    "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunitb",
  ]
  enable_telemetry       = false
  target_resource_type   = "Microsoft.Storage/storageAccounts"
  target_resource_region = "swedencentral"
  static_criteria = {
    transactions = {
      name        = "HighTransactionCount"
      metric_name = "Transactions"
      aggregation = "Total"
      operator    = "GreaterThan"
      threshold   = 100
      dimensions = {
        api = {
          name     = "ApiName"
          operator = "Include"
          values   = ["*"]
        }
      }
    }
  }
}

run "complete_deployment" {
  command = apply

  variables {
    actions = {
      ops = {
        action_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Insights/actionGroups/ag-ops"
      }
    }
    action_properties = {
      "Email.Subject" = "Storage availability degraded"
    }
    auto_mitigate        = false
    description          = "Complete unit test coverage of the metric alert module."
    enabled              = true
    evaluation_frequency = "PT5M"
    lock = {
      kind  = "CanNotDelete"
      notes = "protected"
    }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 15
      max_interval_seconds = 60
    }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "00000000-0000-0000-0000-000000000001"
        principal_type             = "ServicePrincipal"
      }
    }
    severity = 2
    tags = {
      environment = "test"
    }
    timeouts = {
      create = "10m"
      delete = "5m"
      read   = "5m"
      update = "10m"
    }
    window_size = "PT15M"
  }

  assert {
    condition     = azapi_resource.this.body.properties.severity == 2
    error_message = "`severity` must be sent to Azure."
  }
  assert {
    condition     = azapi_resource.this.body.properties.description == "Complete unit test coverage of the metric alert module."
    error_message = "`description` must be sent to Azure."
  }
  assert {
    condition     = azapi_resource.this.body.properties.autoMitigate == false
    error_message = "`auto_mitigate` must be sent to Azure."
  }
  assert {
    condition     = azapi_resource.this.body.properties.actionProperties["Email.Subject"] == "Storage availability degraded"
    error_message = "`action_properties` must be rendered as `actionProperties`."
  }
  assert {
    condition     = azapi_resource.this.tags.environment == "test"
    error_message = "`tags` must be applied to the alert rule."
  }
  assert {
    condition     = azapi_resource.this.timeouts.create == "10m"
    error_message = "`timeouts` must be forwarded to the AzAPI resource."
  }
  assert {
    condition = (
      length(azapi_resource.this.retry.error_message_regex) == 1 &&
      contains(azapi_resource.this.retry.error_message_regex, "ScopeLocked") &&
      azapi_resource.this.retry.interval_seconds == 15 &&
      azapi_resource.this.retry.max_interval_seconds == 60
    )
    error_message = "The alert must preserve the configured lock-propagation retry and backoff."
  }
  assert {
    condition     = azapi_resource.this.timeouts.delete == "5m"
    error_message = "Deletion retries must remain bounded by the configured five-minute timeout."
  }
  assert {
    condition     = length(azapi_resource.lock) == 1
    error_message = "A lock must be created when `var.lock` is supplied."
  }
  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete"
    error_message = "The lock name must default to `lock-<kind>`."
  }
  assert {
    condition     = azapi_resource.lock[0].body.properties.level == "CanNotDelete"
    error_message = "The lock level must be taken from `var.lock.kind`."
  }
  assert {
    condition     = azapi_resource.lock[0].parent_id == azapi_resource.this.id
    error_message = "The lock must be scoped to the alert rule."
  }
  assert {
    condition     = length(azapi_resource.role_assignments) == 1
    error_message = "One role assignment must be created."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id
    error_message = "Role assignments must be scoped to the alert rule."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.principalId == "00000000-0000-0000-0000-000000000001"
    error_message = "The role assignment principal ID must be forwarded."
  }
  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }
}
