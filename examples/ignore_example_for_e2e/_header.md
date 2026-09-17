# Web test availability example (excluded from e2e tests)

This example demonstrates the `webtest_criteria` input, which selects the `Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria` criteria model.

It is excluded from the e2e test run by the `.e2eignore` file in this directory: classic Application Insights web tests depend on outbound internet reachability from the Microsoft-managed test agents, which is not a reliable assumption in the AVM test subscriptions.
