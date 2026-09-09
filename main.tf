module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.7.0"

  enable_telemetry   = var.enable_telemetry
  lock               = var.lock
  managed_identities = var.managed_identities
  # The role-definition lookup is scoped to the parent resource group rather than
  # `azapi_resource.this.id`. Role definitions available at the alert rule are the
  # same as those available at its resource group, and using `var.parent_id` keeps
  # the module free of a dependency cycle between the interfaces module (which
  # supplies the identity block) and the primary resource.
  role_assignment_definition_scope = var.parent_id
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.insights_metric_alerts
  body = {
    properties = local.metric_alert_properties
  }
  ignore_body_changes    = length(var.ignore_body_changes.insights_metric_alerts) > 0 ? var.ignore_body_changes.insights_metric_alerts : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "identity" {
    for_each = module.avm_interfaces.managed_identities_azapi != null ? [module.avm_interfaces.managed_identities_azapi] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    # Exactly one criteria family may be configured. The web test criterion is a
    # single ARM object rather than an `allOf` list, so it cannot be combined with
    # the static or dynamic metric criteria.
    precondition {
      condition     = var.webtest_criteria == null || (length(var.static_criteria) == 0 && length(var.dynamic_criteria) == 0)
      error_message = "`webtest_criteria` cannot be combined with `static_criteria` or `dynamic_criteria`. The Azure Monitor API models web test availability as a single criterion, not as an `allOf` list."
    }
    # The Azure Monitor API requires at least one criterion.
    precondition {
      condition     = var.webtest_criteria != null || length(var.static_criteria) > 0 || length(var.dynamic_criteria) > 0
      error_message = "At least one of `static_criteria`, `dynamic_criteria` or `webtest_criteria` must be supplied."
    }
    # `name` is the Azure-visible criterion identifier and must be unique within
    # `criteria.allOf`. Terraform map keys are identity only and are not sent to Azure.
    precondition {
      condition     = length(local.criteria_names) == length(distinct(local.criteria_names))
      error_message = "Each `static_criteria[*].name` and `dynamic_criteria[*].name` must be unique across both maps. The Azure Monitor API rejects duplicate criterion names."
    }
    # `dimensions[*].name` is the Azure-visible dimension identifier and must be
    # unique within a single criterion.
    precondition {
      condition     = alltrue([for names in local.dimension_name_sets : length(names) == length(distinct(names))])
      error_message = "Each criterion's `dimensions[*].name` values must be unique within that criterion."
    }
    # Multi-resource metric alerts require the target resource type and region so
    # that Azure Monitor can resolve the metric definition for every scope.
    precondition {
      condition     = length(var.scopes) <= 1 || (var.target_resource_type != null && var.target_resource_region != null)
      error_message = "`target_resource_type` and `target_resource_region` are required when `scopes` contains more than one resource ID."
    }
    # Dynamic thresholds are not supported by the web test criteria model.
    precondition {
      condition     = length(var.dynamic_criteria) == 0 || var.webtest_criteria == null
      error_message = "`dynamic_criteria` cannot be used with `webtest_criteria`. Dynamic thresholds are only supported by the multiple-resource metric criteria model."
    }
    # Service-side constraint confirmed by E2E: Azure Monitor rejects a dynamic
    # alert carrying more than one criterion, including a static/dynamic mix, with
    # "Maximum 1 criteria is allowed when using dynamic alert".
    precondition {
      condition     = length(var.dynamic_criteria) == 0 || (length(var.dynamic_criteria) == 1 && length(var.static_criteria) == 0)
      error_message = "A dynamic-threshold alert supports exactly one criterion. Supply a single `dynamic_criteria` entry and no `static_criteria`."
    }
  }
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = local.lock_name
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_locks
  body                   = module.avm_interfaces.lock_azapi.body
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = var.resource_types.authorization_role_assignments
  body                   = each.value.body
  response_export_values = []
  retry = {
    # Retry if a lock is in place on the scope and has only just been removed.
    error_message_regex  = ["ScopeLocked"]
    interval_seconds     = 15
    max_interval_seconds = 60
  }

  timeouts {
    delete = "5m"
  }
}
