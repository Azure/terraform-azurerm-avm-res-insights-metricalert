variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "location" {
  type        = string
  default     = "swedencentral"
  description = "The Azure region used for the supporting resources. Choose a region supporting zone-redundant storage. The metric alert rule itself is always global."
}

variable "notification_email" {
  type        = string
  default     = "operations@contoso.example"
  description = "The operations mailbox for availability notifications. Replace the reserved example address with a monitored mailbox before using this example in production."
}
