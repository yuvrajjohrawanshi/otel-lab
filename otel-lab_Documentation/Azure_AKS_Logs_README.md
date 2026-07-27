---
created: 2026-07-28
type: dev-docs
project: otel-lab
status: active
---

# [[AKS_log]]: Azure Kubernetes Service Log Collection & Telemetry

## Overview
The `AKS_log/` directory serves as the designated location for enterprise Kubernetes container log collection manifests, FluentBit / OpenTelemetry log pipeline templates, and diagnostics configurations for **[[AzureAKS]]** workloads.

## Planned Capabilities
- **Kubernetes Log Routing:** Structured configurations for forwarding stdout/stderr pod logs from `[[easytrade]]` and `[[easyTravel]]` containers.
- **Log Enrichment:** Mapping Kubernetes metadata (pod names, namespaces, container IDs, and deployment labels) onto log records before ingestion into **[[Dynatrace]]** or cloud observability platforms.
