---
created: 2026-07-28
type: dev-docs
project: otel-lab
status: active
---

# [[nodejs-otel-k8s-dynatrace]]: Node.js OpenTelemetry on Kubernetes to Dynatrace

## Overview
The `nodejs-otel-k8s-dynatrace/` folder (formerly `lab1`) contains a Node.js web application (`[[my-otel-app]]`) instrumented with the **[[OpenTelemetry]] SDK** and deployed on Kubernetes alongside an **[[OpenTelemetryCollector]]** that enriches telemetry with Kubernetes metadata and exports to **[[Dynatrace]]**.

## Architecture & Data Flow
1. **Application Layer (`[[my-otel-app]]`):**
   - Built with Express.js (`app.js`).
   - Uses `@opentelemetry/sdk-node` and auto-instrumentations to generate traces and metrics.
   - Exports OTLP gRPC telemetry on port `4317` to the standalone Collector service.
2. **Collector Layer (`[[otel-collector]]`):**
   - Deployed as a Kubernetes Deployment and ConfigMap (`k8s/collector.yaml`).
   - Receives OTLP telemetry from the application pod.
   - Scrapes Kubernetes cluster metrics (`k8s_cluster`), node/pod metrics (`kubeletstats`), and Kubernetes events (`k8s_events`).
   - Enriches spans and metrics using the `k8sattributes` processor.
   - Forwards processed OTLP HTTP telemetry directly to the **[[Dynatrace]]** ingest endpoint.

## Key Files & Directories
- [app.js](file:///f:/otel-lab/nodejs-otel-k8s-dynatrace/app.js): Core Express application with OTel SDK initialization.
- [Dockerfile](file:///f:/otel-lab/nodejs-otel-k8s-dynatrace/Dockerfile): Container build instructions for `[[my-otel-app]]`.
- [k8s/](file:///f:/otel-lab/nodejs-otel-k8s-dynatrace/k8s): Kubernetes manifests including `[[namespace.yaml]]`, `[[collector.yaml]]`, `[[deployment.yaml]]`, and `[[service.yaml]]`.
- [agent/](file:///f:/otel-lab/nodejs-otel-k8s-dynatrace/agent): Systemd service and environment configs (`[[otel-agent.service]]`) for Linux VM host deployments.
