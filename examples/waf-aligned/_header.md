# WAF-aligned example

This runnable example demonstrates applicable [Azure Well-Architected Framework guidance for Azure Monitor alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/best-practices-alerts).

The enabled, severity-2 metric alert monitors average storage availability below 99.9 percent over a 15-minute window, evaluated every five minutes. Its enabled action group uses the common alert schema and an operations email receiver. Automatic mitigation resolves the stateful alert when availability recovers, reducing repeat notifications.

The monitored storage account uses zone-redundant storage, HTTPS with TLS 1.2, disabled shared-key authorization and anonymous blob access, and disabled public network access with a deny-by-default firewall. Platform metric collection does not require opening the storage data endpoint. A single monitored resource and one metric keep the example small and avoid unsupported multi-resource storage alerts.

Before production use, replace `notification_email` with a monitored mailbox and tune the threshold, severity, and evaluation window to the workload's service objectives. The default email uses a reserved example domain so automated E2E runs do not contact a real recipient. E2E validates deployment, idempotency, and cleanup, not email delivery or a simulated availability incident. Choose a region that supports zone-redundant storage.

This is an illustrative metric-alert configuration, not a complete workload architecture or WAF certification. Service Health and Resource Health alerts complement this rule but are different resource types and are outside this module's scope. Log-query managed identities, workspace encryption, and private endpoints are not applicable to this metric alert rule.

The example is automatically discovered as the required `waf-aligned` E2E scenario alongside `default`. Run it with the managed authoring toolchain:

```powershell
$env:TF_VAR_enable_telemetry = "false"
avm test e2e --example waf-aligned
```
