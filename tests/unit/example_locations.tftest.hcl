mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "modtm" {}
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
