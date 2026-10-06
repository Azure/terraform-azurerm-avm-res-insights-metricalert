# Dynamic threshold example

This example deploys a metric alert rule that uses machine-learned dynamic thresholds instead of fixed static thresholds.

Dynamic thresholds are only supported by the `Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria` model, so supplying any entry in `dynamic_criteria` makes the module select that criteria model automatically.

Azure Monitor allows exactly one criterion on a dynamic alert rule, so this example supplies a single `dynamic_criteria` entry.
