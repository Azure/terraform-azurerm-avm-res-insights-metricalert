# `Microsoft.Insights/metricAlerts` is a global ARM resource type: the service
# only accepts `location = "global"` and rejects every Azure region. Requiring
# consumers to pass a location that has exactly one legal value adds friction
# without adding choice, so `var.location` keeps its `"global"` default and is
# validated to reject anything else.
#
# `var.location` itself cannot be removed because the centrally managed
# `main.telemetry.tf` reads it through `local.main_location`.
#
# Scope: root module only. All other AVM interface rules stay enforced.
rule "avm_interface_location" {
  enabled = false
}
