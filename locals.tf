locals {
  # The Azure Monitor `criteria` property is an ARM discriminated object keyed on
  # `odata.type`. AzAPI validates the configured body against the schema of the
  # selected variant, so keys that belong to the other variant must be absent
  # rather than null. The `merge([for ...]...)` form emits a partial object only
  # when the variant is selected and avoids Terraform having to unify two
  # different object types in a conditional expression.
  criteria = merge(
    { "odata.type" = local.criteria_odata_type },
    local.criteria_part_metric,
    local.criteria_part_webtest,
  )
  criteria_dynamic = [
    for k, v in var.dynamic_criteria : {
      criterionType    = "DynamicThresholdCriterion"
      name             = v.name
      metricName       = v.metric_name
      metricNamespace  = v.metric_namespace
      timeAggregation  = v.aggregation
      operator         = v.operator
      alertSensitivity = v.alert_sensitivity
      failingPeriods = {
        numberOfEvaluationPeriods = v.number_of_evaluation_periods
        minFailingPeriodsToAlert  = v.min_failing_periods_to_alert
      }
      ignoreDataBefore     = v.ignore_data_before
      skipMetricValidation = v.skip_metric_validation
      dimensions = length(v.dimensions) > 0 ? [
        for dk, dv in v.dimensions : {
          name     = dv.name
          operator = dv.operator
          values   = tolist(dv.values)
        }
      ] : null
    }
  ]
  # Every Azure-visible criterion name across both criteria maps, used by the
  # uniqueness precondition in `main.tf`.
  criteria_names = concat(
    [for k, v in var.static_criteria : v.name],
    [for k, v in var.dynamic_criteria : v.name],
  )
  # Dynamic thresholds and multi-resource scopes are only supported by the
  # multiple-resource criteria model. Single-resource static alerts keep the
  # narrower model so that the Azure portal renders them as classic metric alerts.
  criteria_odata_type = (
    var.webtest_criteria != null
    ? "Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria"
    : (
      length(var.dynamic_criteria) > 0 || length(var.scopes) > 1 || var.target_resource_type != null
      ? "Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria"
      : "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
    )
  )
  # `allOf` is only present for the metric criteria variants. Map iteration is in
  # lexical key order, so the rendered list is stable across plans.
  criteria_part_metric = merge([
    for _ in(var.webtest_criteria == null ? [true] : []) : {
      allOf = concat(local.criteria_static, local.criteria_dynamic)
    }
  ]...)
  criteria_part_webtest = merge([
    for c in(var.webtest_criteria == null ? [] : [var.webtest_criteria]) : {
      webTestId           = c.web_test_id
      componentId         = c.component_id
      failedLocationCount = c.failed_location_count
    }
  ]...)
  criteria_static = [
    for k, v in var.static_criteria : {
      criterionType        = "StaticThresholdCriterion"
      name                 = v.name
      metricName           = v.metric_name
      metricNamespace      = v.metric_namespace
      timeAggregation      = v.aggregation
      operator             = v.operator
      threshold            = v.threshold
      skipMetricValidation = v.skip_metric_validation
      dimensions = length(v.dimensions) > 0 ? [
        for dk, dv in v.dimensions : {
          name     = dv.name
          operator = dv.operator
          values   = tolist(dv.values)
        }
      ] : null
    }
  ]
  # Azure-visible dimension names grouped per criterion, used by the uniqueness
  # precondition in `main.tf`.
  dimension_name_sets = concat(
    [for k, v in var.static_criteria : [for dk, dv in v.dimensions : dv.name]],
    [for k, v in var.dynamic_criteria : [for dk, dv in v.dimensions : dv.name]],
  )
  # The lock name is optional on the AVM interface; fall back to the AVM
  # convention of `lock-<kind>` when the consumer does not supply one.
  lock_name = var.lock == null ? null : coalesce(var.lock.name, "lock-${var.lock.kind}")
  metric_alert_actions = [
    for k, v in var.actions : {
      actionGroupId     = v.action_group_id
      webHookProperties = v.webhook_properties
    }
  ]
  # AzAPI validates the *configured* body against the schema of the API version
  # pinned by `var.resource_types` before it strips null values, so an optional
  # property must be absent rather than null. Merging each optional property in
  # only when the consumer sets it keeps the module usable when an older API
  # version is pinned, and keeps the request body free of meaningless nulls.
  metric_alert_properties = merge(
    {
      autoMitigate        = var.auto_mitigate
      criteria            = local.criteria
      enabled             = var.enabled
      evaluationFrequency = var.evaluation_frequency
      scopes              = tolist(var.scopes)
      severity            = var.severity
      windowSize          = var.window_size
    },
    merge([for v in(var.action_properties == null ? [] : [var.action_properties]) : { actionProperties = v }]...),
    merge([for v in(length(var.actions) == 0 ? [] : [local.metric_alert_actions]) : { actions = v }]...),
    merge([for v in(var.custom_properties == null ? [] : [var.custom_properties]) : { customProperties = v }]...),
    merge([for v in(var.description == null ? [] : [var.description]) : { description = v }]...),
    merge([for v in(var.target_resource_region == null ? [] : [var.target_resource_region]) : { targetResourceRegion = v }]...),
    merge([for v in(var.target_resource_type == null ? [] : [var.target_resource_type]) : { targetResourceType = v }]...),
  )
}
