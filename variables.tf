variable "name" {
  type        = string
  description = "The name of the Azure Monitor metric alert rule."
  nullable    = false

  validation {
    condition     = can(regex("^[^<>*%&:?+/\\\\#]{1,260}$", var.name)) && !can(regex("[.\\s]$", var.name))
    error_message = "`name` must be 1-260 characters, must not contain any of `<>*%&:?+/\\#`, and must not end with a period or whitespace."
  }
}

variable "parent_id" {
  type        = string
  description = "The fully-qualified ARM resource ID of the existing resource group into which the metric alert rule will be deployed."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid resource group resource ID."
  }
}

variable "scopes" {
  type        = set(string)
  description = <<DESCRIPTION
The set of fully-qualified ARM resource IDs that the metric alert rule evaluates. This maps to `Microsoft.Insights/metricAlerts.properties.scopes`.

All scopes must be of the same resource type and, for multi-resource alerts, must live in the same region. When more than one scope is supplied, `target_resource_type` and `target_resource_region` are required by the Azure Monitor API.

This input is intentionally polymorphic: any Azure resource type that emits metrics may be targeted, so per-type resource ID validation is not applied. See TFNFR38.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.scopes) > 0
    error_message = "`scopes` must contain at least one resource ID. Azure Monitor rejects a metric alert rule with an empty scope list."
  }
  validation {
    condition     = alltrue([for s in var.scopes : can(regex("^/subscriptions/[^/]+(/.+)?$", s))])
    error_message = "Each entry in `scopes` must be a non-empty, fully-qualified ARM resource ID beginning with `/subscriptions/`."
  }
}

variable "action_properties" {
  type        = map(string)
  default     = null
  description = "(Optional) A map of properties passed to the configured action groups when the alert fires. This maps to `Microsoft.Insights/metricAlerts.properties.actionProperties`."
}

variable "actions" {
  type = map(object({
    action_group_id    = string
    webhook_properties = optional(map(string), null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of action group associations to invoke when the alert fires. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time; it is used for Terraform identity only and is never sent to Azure.

- `action_group_id` - The fully-qualified ARM resource ID of the action group to invoke.
- `webhook_properties` - (Optional) A map of custom properties sent to the webhook payloads of the action group.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.actions :
      can(provider::azapi::parse_resource_id("Microsoft.Insights/actionGroups", v.action_group_id))
    ])
    error_message = "Each `actions[*].action_group_id` must be a valid, non-empty `Microsoft.Insights/actionGroups` resource ID."
  }
}

variable "auto_mitigate" {
  type        = bool
  default     = true
  description = "(Optional) Whether the alert is automatically resolved when the condition is no longer met. This maps to `Microsoft.Insights/metricAlerts.properties.autoMitigate`."
  nullable    = false
}

variable "custom_properties" {
  type        = map(string)
  default     = null
  description = "(Optional) A map of custom properties carried on the fired alert payload. This maps to `Microsoft.Insights/metricAlerts.properties.customProperties`."
}

variable "description" {
  type        = string
  default     = null
  description = "(Optional) The description of the metric alert rule that is included in the alert notification. This maps to `Microsoft.Insights/metricAlerts.properties.description`."
}

variable "dynamic_criteria" {
  type = map(object({
    name                         = string
    metric_name                  = string
    metric_namespace             = optional(string, null)
    aggregation                  = string
    operator                     = string
    alert_sensitivity            = string
    number_of_evaluation_periods = optional(number, 4)
    min_failing_periods_to_alert = optional(number, 4)
    ignore_data_before           = optional(string, null)
    skip_metric_validation       = optional(bool, null)
    dimensions = optional(map(object({
      name     = string
      operator = string
      values   = set(string)
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of dynamic-threshold criteria. Each entry becomes a `DynamicThresholdCriterion` element of `Microsoft.Insights/metricAlerts.properties.criteria.allOf`.

The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time; it is used for Terraform identity only. The Azure-visible criterion name is taken from `name`, and the Azure-visible dimension name is taken from `dimensions[*].name`.

Dynamic thresholds are only supported by the multiple-resource criteria model, so supplying any entry here forces `criteria."odata.type"` to `Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria`.

- `name` - The Azure-visible name of the criterion. Must be unique across `static_criteria` and `dynamic_criteria`.
- `metric_name` - The name of the metric to evaluate.
- `metric_namespace` - (Optional) The namespace of the metric.
- `aggregation` - The time aggregation applied to the metric. Possible values are `Average`, `Count`, `Minimum`, `Maximum` and `Total`.
- `operator` - The comparison operator. Possible values are `GreaterThan`, `LessThan` and `GreaterOrLessThan`.
- `alert_sensitivity` - The extent of deviation required to trigger the alert. Possible values are `Low`, `Medium` and `High`.
- `number_of_evaluation_periods` - (Optional) The number of lookback time windows considered. Defaults to `4`.
- `min_failing_periods_to_alert` - (Optional) The number of violations required within the lookback windows. Must be less than or equal to `number_of_evaluation_periods`. Defaults to `4`.
- `ignore_data_before` - (Optional) An ISO 8601 timestamp. Historical metric data before this point is excluded from threshold learning.
- `skip_metric_validation` - (Optional) Allows a custom metric that is not yet emitted to be used in the criterion.
- `dimensions` - (Optional) A map of dimension filters. The map key is arbitrary Terraform identity.
  - `name` - The Azure-visible name of the dimension.
  - `operator` - The dimension operator. Possible values are `Include` and `Exclude`.
  - `values` - The set of dimension values to match. Use `["*"]` to match all values.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.dynamic_criteria : contains(["Average", "Count", "Minimum", "Maximum", "Total"], v.aggregation)
    ])
    error_message = "Each `dynamic_criteria[*].aggregation` must be one of `Average`, `Count`, `Minimum`, `Maximum` or `Total`."
  }
  validation {
    condition = alltrue([
      for _, v in var.dynamic_criteria : contains(["GreaterThan", "LessThan", "GreaterOrLessThan"], v.operator)
    ])
    error_message = "Each `dynamic_criteria[*].operator` must be one of `GreaterThan`, `LessThan` or `GreaterOrLessThan`."
  }
  validation {
    condition = alltrue([
      for _, v in var.dynamic_criteria : contains(["Low", "Medium", "High"], v.alert_sensitivity)
    ])
    error_message = "Each `dynamic_criteria[*].alert_sensitivity` must be one of `Low`, `Medium` or `High`."
  }
  validation {
    condition = alltrue([
      for _, v in var.dynamic_criteria :
      v.number_of_evaluation_periods >= 1 && v.number_of_evaluation_periods <= 6 &&
      v.min_failing_periods_to_alert >= 1 && v.min_failing_periods_to_alert <= 6 &&
      v.min_failing_periods_to_alert <= v.number_of_evaluation_periods
    ])
    error_message = "Each `dynamic_criteria[*]` must set `number_of_evaluation_periods` and `min_failing_periods_to_alert` between 1 and 6, with `min_failing_periods_to_alert` less than or equal to `number_of_evaluation_periods`."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.dynamic_criteria : [
        for _, d in v.dimensions : contains(["Include", "Exclude"], d.operator)
      ]
    ]))
    error_message = "Each `dynamic_criteria[*].dimensions[*].operator` must be either `Include` or `Exclude`."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.dynamic_criteria : [
        for _, d in v.dimensions : length(d.values) > 0
      ]
    ]))
    error_message = "Each `dynamic_criteria[*].dimensions[*].values` must contain at least one value."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "enabled" {
  type        = bool
  default     = true
  description = "(Optional) Whether the metric alert rule is enabled. This maps to `Microsoft.Insights/metricAlerts.properties.enabled`."
  nullable    = false
}

variable "evaluation_frequency" {
  type        = string
  default     = "PT1M"
  description = "(Optional) How often the metric alert rule is evaluated, as an ISO 8601 duration. Possible values are `PT1M`, `PT5M`, `PT15M`, `PT30M` and `PT1H`. This maps to `Microsoft.Insights/metricAlerts.properties.evaluationFrequency`."
  nullable    = false

  validation {
    condition     = contains(["PT1M", "PT5M", "PT15M", "PT30M", "PT1H"], var.evaluation_frequency)
    error_message = "`evaluation_frequency` must be one of `PT1M`, `PT5M`, `PT15M`, `PT30M` or `PT1H`."
  }
}

variable "ignore_body_changes" {
  type = object({
    insights_metric_alerts = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore for each AzAPI resource. Paths use dot notation, for example `properties.criteria`. Changes take effect only after apply, because the value is held in provider-private state. Ignored configuration is not sent to Azure until the path is removed from the list.

Supplying a non-empty value requires Terraform 1.11 or later.

- `insights_metric_alerts` - Paths ignored on the `Microsoft.Insights/metricAlerts` resource.
DESCRIPTION
  nullable    = false
}

variable "location" {
  type        = string
  default     = "global"
  description = "(Optional) The Azure region of the metric alert rule. `Microsoft.Insights/metricAlerts` is a global resource type, so `global` is the only value the Azure Monitor API accepts."
  nullable    = false

  validation {
    condition     = lower(var.location) == "global"
    error_message = "`location` must be `global`. `Microsoft.Insights/metricAlerts` is a global resource type."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.

> Note: the `Microsoft.Insights/metricAlerts` ARM schema restricts `identity.type` to `SystemAssigned`, `UserAssigned` or `None`. The combined `SystemAssigned, UserAssigned` value is not accepted, so `system_assigned` and `user_assigned_resource_ids` are mutually exclusive on this resource type.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in var.managed_identities.user_assigned_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
  validation {
    condition     = !(var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0)
    error_message = "`managed_identities.system_assigned` and `managed_identities.user_assigned_resource_ids` are mutually exclusive. `Microsoft.Insights/metricAlerts` only accepts an `identity.type` of `SystemAssigned`, `UserAssigned` or `None`."
  }
}

variable "resource_types" {
  type = object({
    insights_metric_alerts         = optional(string, "Microsoft.Insights/metricAlerts@2026-01-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by the module. Each key defaults to a tested value; supply only the keys you want to override. Useful when targeting a sovereign cloud with older API versions.

- `insights_metric_alerts` - Resource type and API version for the metric alert rule.
- `authorization_locks` - Resource type and API version for the management lock.
- `authorization_role_assignments` - Resource type and API version for role assignments.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the metric alert rule. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "severity" {
  type        = number
  default     = 3
  description = "(Optional) The severity of the alert, where `0` is the most severe and `4` the least. This maps to `Microsoft.Insights/metricAlerts.properties.severity`."
  nullable    = false

  validation {
    condition     = contains([0, 1, 2, 3, 4], var.severity)
    error_message = "`severity` must be an integer between 0 and 4 inclusive."
  }
}

variable "static_criteria" {
  type = map(object({
    name                   = string
    metric_name            = string
    metric_namespace       = optional(string, null)
    aggregation            = string
    operator               = string
    threshold              = number
    skip_metric_validation = optional(bool, null)
    dimensions = optional(map(object({
      name     = string
      operator = string
      values   = set(string)
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of static-threshold criteria. Each entry becomes a `StaticThresholdCriterion` element of `Microsoft.Insights/metricAlerts.properties.criteria.allOf`.

The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time; it is used for Terraform identity only. The Azure-visible criterion name is taken from `name`, and the Azure-visible dimension name is taken from `dimensions[*].name`.

- `name` - The Azure-visible name of the criterion. Must be unique across `static_criteria` and `dynamic_criteria`.
- `metric_name` - The name of the metric to evaluate.
- `metric_namespace` - (Optional) The namespace of the metric.
- `aggregation` - The time aggregation applied to the metric. Possible values are `Average`, `Count`, `Minimum`, `Maximum` and `Total`.
- `operator` - The comparison operator. Possible values are `Equals`, `GreaterThan`, `GreaterThanOrEqual`, `LessThan` and `LessThanOrEqual`.
- `threshold` - The threshold the aggregated metric is compared against.
- `skip_metric_validation` - (Optional) Allows a custom metric that is not yet emitted to be used in the criterion.
- `dimensions` - (Optional) A map of dimension filters. The map key is arbitrary Terraform identity.
  - `name` - The Azure-visible name of the dimension.
  - `operator` - The dimension operator. Possible values are `Include` and `Exclude`.
  - `values` - The set of dimension values to match. Use `["*"]` to match all values.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.static_criteria : contains(["Average", "Count", "Minimum", "Maximum", "Total"], v.aggregation)
    ])
    error_message = "Each `static_criteria[*].aggregation` must be one of `Average`, `Count`, `Minimum`, `Maximum` or `Total`."
  }
  validation {
    condition = alltrue([
      for _, v in var.static_criteria :
      contains(["Equals", "GreaterThan", "GreaterThanOrEqual", "LessThan", "LessThanOrEqual"], v.operator)
    ])
    error_message = "Each `static_criteria[*].operator` must be one of `Equals`, `GreaterThan`, `GreaterThanOrEqual`, `LessThan` or `LessThanOrEqual`."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.static_criteria : [
        for _, d in v.dimensions : contains(["Include", "Exclude"], d.operator)
      ]
    ]))
    error_message = "Each `static_criteria[*].dimensions[*].operator` must be either `Include` or `Exclude`."
  }
  validation {
    condition = alltrue(flatten([
      for _, v in var.static_criteria : [
        for _, d in v.dimensions : length(d.values) > 0
      ]
    ]))
    error_message = "Each `static_criteria[*].dimensions[*].values` must contain at least one value."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "target_resource_region" {
  type        = string
  default     = null
  description = "(Optional) The region of the resources being monitored. Required by the Azure Monitor API when `scopes` contains more than one resource ID. This maps to `Microsoft.Insights/metricAlerts.properties.targetResourceRegion`."
}

variable "target_resource_type" {
  type        = string
  default     = null
  description = "(Optional) The resource type of the resources being monitored, for example `Microsoft.Compute/virtualMachines`. Required by the Azure Monitor API when `scopes` contains more than one resource ID. This maps to `Microsoft.Insights/metricAlerts.properties.targetResourceType`."

  validation {
    condition     = var.target_resource_type == null || can(regex("^[^/]+/[^/]+$", coalesce(var.target_resource_type, "x/y")))
    error_message = "`target_resource_type` must be a `<provider-namespace>/<resource-type>` string, for example `Microsoft.Compute/virtualMachines`."
  }
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}

variable "webtest_criteria" {
  type = object({
    web_test_id           = string
    component_id          = string
    failed_location_count = number
  })
  default     = null
  description = <<DESCRIPTION
(Optional) A single web test availability criterion. Supplying this value sets `criteria."odata.type"` to `Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria`.

The Azure Monitor API models this criteria type as a single object rather than a list, so it cannot be combined with `static_criteria` or `dynamic_criteria`.

- `web_test_id` - The fully-qualified ARM resource ID of the `Microsoft.Insights/webtests` resource.
- `component_id` - The fully-qualified ARM resource ID of the `Microsoft.Insights/components` (Application Insights) resource.
- `failed_location_count` - The number of failed locations required to raise the alert.
DESCRIPTION

  validation {
    condition     = var.webtest_criteria == null || can(provider::azapi::parse_resource_id("Microsoft.Insights/webtests", try(var.webtest_criteria.web_test_id, "")))
    error_message = "`webtest_criteria.web_test_id` must be a valid `Microsoft.Insights/webtests` resource ID."
  }
  validation {
    condition     = var.webtest_criteria == null || can(provider::azapi::parse_resource_id("Microsoft.Insights/components", try(var.webtest_criteria.component_id, "")))
    error_message = "`webtest_criteria.component_id` must be a valid `Microsoft.Insights/components` resource ID."
  }
  validation {
    condition     = var.webtest_criteria == null || try(var.webtest_criteria.failed_location_count, 0) >= 1
    error_message = "`webtest_criteria.failed_location_count` must be at least 1."
  }
}

variable "window_size" {
  type        = string
  default     = "PT5M"
  description = <<DESCRIPTION
(Optional) The period over which the metric values are aggregated, as an ISO 8601 duration. Possible values are `PT1M`, `PT5M`, `PT15M`, `PT30M`, `PT1H`, `PT6H`, `PT12H` and `P1D`. Must be greater than or equal to `evaluation_frequency`. This maps to `Microsoft.Insights/metricAlerts.properties.windowSize`.
DESCRIPTION
  nullable    = false

  validation {
    condition     = contains(["PT1M", "PT5M", "PT15M", "PT30M", "PT1H", "PT6H", "PT12H", "P1D"], var.window_size)
    error_message = "`window_size` must be one of `PT1M`, `PT5M`, `PT15M`, `PT30M`, `PT1H`, `PT6H`, `PT12H` or `P1D`."
  }
  validation {
    condition = lookup({
      PT1M  = 1
      PT5M  = 5
      PT15M = 15
      PT30M = 30
      PT1H  = 60
      PT6H  = 360
      PT12H = 720
      P1D   = 1440
      }, var.window_size, 0) >= lookup({
      PT1M  = 1
      PT5M  = 5
      PT15M = 15
      PT30M = 30
      PT1H  = 60
    }, var.evaluation_frequency, 0)
    error_message = "`window_size` must be greater than or equal to `evaluation_frequency`."
  }
}
