provider "azapi" {}

variables {
  enable_telemetry = true
}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

# Create the alert rule with a single static criterion.
run "create" {
  variables {
    name      = "alert-avm-${run.setup.name_suffix}"
    parent_id = run.setup.resource_group_id
    scopes    = [run.setup.storage_account_id]
    actions = {
      ops = {
        action_group_id = run.setup.action_group_id
      }
    }
    description = "AVM integration test for the metric alert module."
    severity    = 3
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThan"
        threshold   = 100
      }
    }
    tags = {
      scenario = "integration"
    }
  }

  assert {
    condition     = output.name == "alert-avm-${run.setup.name_suffix}"
    error_message = "The alert rule must be created with the requested name."
  }
  assert {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Insights/metricAlerts", output.resource_id))
    error_message = "The module must return a well formed metric alert resource ID."
  }
  assert {
    condition     = output.resource.body.properties.enabled == true
    error_message = "The applied alert rule must be enabled."
  }
  assert {
    condition     = length(output.resource.body.properties.criteria.allOf) == 1
    error_message = "The applied alert rule must carry exactly one criterion."
  }
}

# Update in place: severity, threshold, enablement, an added dimension, a lock
# and a second action group.
run "update" {
  variables {
    name      = "alert-avm-${run.setup.name_suffix}"
    parent_id = run.setup.resource_group_id
    scopes    = [run.setup.storage_account_id]
    actions = {
      ops = {
        action_group_id = run.setup.action_group_id
        webhook_properties = {
          runbook = "storage-availability"
        }
      }
    }
    description          = "AVM integration test for the metric alert module (updated)."
    enabled              = false
    evaluation_frequency = "PT5M"
    lock = {
      kind = "CanNotDelete"
    }
    severity = 1
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThanOrEqual"
        threshold   = 250
        dimensions = {
          api = {
            name     = "ApiName"
            operator = "Include"
            values   = ["*"]
          }
        }
      }
    }
    tags = {
      scenario = "integration"
      stage    = "updated"
    }
    window_size = "PT15M"
  }

  assert {
    condition     = output.resource_id == run.create.resource_id
    error_message = "The alert rule must be updated in place rather than replaced."
  }
  assert {
    condition     = output.resource.body.properties.severity == 1
    error_message = "The applied alert rule must carry the updated severity."
  }
  assert {
    condition     = output.resource.body.properties.enabled == false
    error_message = "The applied alert rule must be disabled after the update."
  }
  assert {
    condition     = output.resource.body.properties.criteria.allOf[0].threshold == 250
    error_message = "The applied alert rule must carry the updated threshold."
  }
  assert {
    condition     = length(output.resource.body.properties.criteria.allOf[0].dimensions) == 1
    error_message = "The applied alert rule must carry the added dimension."
  }
  assert {
    condition     = output.resource.tags.stage == "updated"
    error_message = "The applied alert rule must carry the updated tags."
  }
}

# Re-applying the same configuration must produce an empty plan.
run "idempotency" {
  command = plan

  variables {
    name      = "alert-avm-${run.setup.name_suffix}"
    parent_id = run.setup.resource_group_id
    scopes    = [run.setup.storage_account_id]
    actions = {
      ops = {
        action_group_id = run.setup.action_group_id
        webhook_properties = {
          runbook = "storage-availability"
        }
      }
    }
    description          = "AVM integration test for the metric alert module (updated)."
    enabled              = false
    evaluation_frequency = "PT5M"
    lock = {
      kind = "CanNotDelete"
    }
    severity = 1
    static_criteria = {
      transactions = {
        name        = "HighTransactionCount"
        metric_name = "Transactions"
        aggregation = "Total"
        operator    = "GreaterThanOrEqual"
        threshold   = 250
        dimensions = {
          api = {
            name     = "ApiName"
            operator = "Include"
            values   = ["*"]
          }
        }
      }
    }
    tags = {
      scenario = "integration"
      stage    = "updated"
    }
    window_size = "PT15M"
  }

  assert {
    condition     = output.resource_id == run.update.resource_id
    error_message = "A repeated plan of an unchanged configuration must not replace the alert rule."
  }
}
