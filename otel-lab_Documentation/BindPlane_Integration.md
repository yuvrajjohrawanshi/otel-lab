---
created: 2026-07-27
type: dev-docs
project: otel-lab
status: active
---

# [[BindPlane]] OP Integration & Control Plane Guide

## Overview
**[[BindPlane]] OP (Observability Pipeline)** by ObservIQ is an enterprise-grade graphical control plane designed to manage fleets of **OpenTelemetry Collectors** at scale.

In our current lab architecture, we manually configure the OpenTelemetry Collector using a Kubernetes `ConfigMap` (`otel-collector-config.yaml`). While effective for standalone deployments, managing manual YAML configurations across dozens of clusters, namespaces, and telemetry vendors becomes challenging.

Integrating **[[BindPlane]]** transforms your OpenTelemetry Collectors into dynamically managed agents configured entirely through a web UI using the OpenTelemetry Agent Management Protocol (**OpAMP**).

---

## Architecture: With vs. Without [[BindPlane]]

### Current Static Architecture
```text
easyTravel Pods (initContainer) ---> OTel Collector (Static K8s ConfigMap) ---> New Relic (US)
```

### Dynamic Architecture with [[BindPlane]] Control Plane
```text
                                  +-----------------------+
                                  |   BindPlane Control   |
                                  |    Plane (Web UI)     |
                                  +-----------+-----------+
                                              |
                                              | (OpAMP Protocol / Dynamic Configs)
                                              v
easyTravel Pods (initContainer) ---> OTel Collector Agent ---> New Relic (US)
```

1. **easyTravel App (`[[backend]]`, `[[angular-frontend]]`):** Continues sending OTLP traces and metrics to the local Collector on port `4318` (HTTP) or `4317` (gRPC).
2. **OTel Collector Agent:** Runs in Kubernetes with a lightweight initial boot config that connects it to the [[BindPlane]] server.
3. **[[BindPlane]] Control Plane:** Manages the pipeline configuration dynamically, pushing updates to the Collector without pod restarts.

---

## What Can You Do From the [[BindPlane]] UI?

### 1. Visual No-Code Pipeline Builder
- **Graphical Drag-and-Drop:** Build complex OTel pipelines by visually connecting **Sources** (Receivers), **Processors**, and **Destinations** (Exporters) without writing a single line of YAML.
- **Source Templates:** Pre-built configurations for OTLP (gRPC/HTTP), Kubernetes cluster metrics, host metrics, Prometheus scrapers, and application logs.

### 2. Destination Management & New Relic Integration
- **Form-Based Credential Storage:** Configure **New Relic** (US or EU regions) using a clean GUI form.
- **Secret Protection:** License keys (`3f25decf...NRAL`) are stored securely in [[BindPlane]] rather than exposed in plain text Kubernetes ConfigMaps or scripts.
- **Multi-Destination Fan-Out:** Send the same easyTravel telemetry simultaneously to **New Relic**, Datadog, Splunk, or an S3 archival bucket with a single click.

### 3. Live Data Preview & Troubleshooting
- **Real-Time Stream Inspection:** Click on any node in your pipeline to inspect live traces, metrics, and logs flowing through the Collector in real time directly in your browser.
- **Instant Validation:** Verify that spans from `[[backend]]` or `[[angular-frontend]]` have the correct resource attributes (`service.name`) *before* they are sent to New Relic.

### 4. Advanced Ingest Control & PII Redaction
- **Noisy Span Filtering:** Add visual filtering processors to drop repetitive health check endpoints (`/health`, `/metrics`) or simulated errors from `[[loadgenerator]]`.
- **PII Redaction & Security:** Strip sensitive customer data (credit cards, passwords, emails) from HTTP headers or SQL query strings automatically before leaving your Kubernetes cluster.
- **Cost Reduction (Sampling):** Visually configure **Tail-Based Sampling** or **Probabilistic Sampling** to keep 100% of error traces while retaining only 10% of successful HTTP 200 requests, dramatically lowering New Relic ingest costs.

### 5. Fleet Health & Resource Monitoring
- **Centralized Dashboard:** View the health status, uptime, throughput (Events/sec, MB/sec), and dropped span counts across all running OpenTelemetry Collectors in your cluster.
- **Resource Usage Alerting:** Track Collector CPU and Memory consumption to detect memory leaks or queue bottlenecks before pods are OOM-killed.

---

## How to Integrate [[BindPlane]] (Without Modifying Current Files)

To add [[BindPlane]] to your cluster alongside the current lab setup:

### Step 1: Deploy [[BindPlane]] OP Server
You can deploy the community edition of **BindPlane OP** into your Kubernetes cluster using Helm or a standard deployment manifest:
```bash
helm repo add observiq https://observiq.github.io/bindplane-op-helm
helm install bindplane observiq/bindplane -n otel-demo
```
*(Alternatively, you can use the managed cloud SaaS version at [observIO Cloud](https://observiq.com)).*

### Step 2: Create a Configuration in the UI
1. Access the [[BindPlane]] UI via `kubectl port-forward svc/bindplane -n otel-demo 3001:3001`.
2. Click **Configurations -> Create Configuration**.
3. Add an **OTLP Source** (ports `4317` / `4318`).
4. Add a **New Relic Destination** and paste your Ingest License Key.

### Step 3: Connect a Collector Agent via OpAMP
When you create an agent in [[BindPlane]], it generates a lightweight Kubernetes command containing your **Secret Key** and **OpAMP Endpoint**:
```yaml
env:
  - name: OPAMP_ENDPOINT
    value: "ws://bindplane.otel-demo.svc.cluster.local:3001/v1/opamp"
  - name: OPAMP_SECRET_KEY
    value: "<YOUR_BINDPLANE_SECRET_KEY>"
```
Once deployed, the Collector registers in the [[BindPlane]] UI, and you can control 100% of its telemetry routing from your browser!
