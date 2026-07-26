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

## How to Integrate [[BindPlane]] SaaS (Without Modifying Current Files)

Using **BindPlane SaaS (observIQ Cloud)** is the ideal choice for resource-constrained environments like KillerCoda because **zero control-plane infrastructure runs in your Kubernetes cluster**. You only run lightweight Collector agents that connect to the cloud control plane via WebSockets (`wss://`).

### Step 1: Log in to BindPlane SaaS
1. Log in to your **[BindPlane SaaS / observIQ Cloud](https://app.observiq.com)** tenant.
2. Navigate to **Configurations -> Create Configuration**.

### Step 2: Configure Your Pipeline in the SaaS UI
1. Add an **OTLP Source**:
   - Enable HTTP (`4318`) and gRPC (`4317`) receivers.
2. Add a **New Relic Destination**:
   - Select **New Relic**.
   - Enter your New Relic US Ingest License Key (`3f25decf...NRAL`).
   - Save the configuration.

### Step 3: Install the BindPlane SaaS Agent in Kubernetes
1. In the BindPlane SaaS portal, go to **Agents -> Install Agent**.
2. Select **Kubernetes** as your operating system.
3. Copy the generated `helm install` or `kubectl apply` command provided by BindPlane SaaS. It automatically includes your tenant's OpAMP credentials:
   ```yaml
   env:
     - name: OPAMP_ENDPOINT
       value: "wss://opamp.observiq.com/v1/opamp"
     - name: OPAMP_SECRET_KEY
       value: "<YOUR_BINDPLANE_SAAS_SECRET_KEY>"
     - name: OPAMP_AGENT_NAME
       value: "killercoda-otel-agent"
   ```
4. Deploy the agent to your `otel-demo` namespace.

### Step 4: Route easyTravel Telemetry to the BindPlane Agent
Once the BindPlane agent pod is running in Kubernetes, it automatically registers in your SaaS dashboard. 

Your `[[backend]]` and `[[angular-frontend]]` pods can send traces to this agent immediately, and you can edit 100% of your telemetry rules, filters, and New Relic forwarding from [app.observiq.com](https://app.observiq.com) without ever touching a YAML file!

---

## How to Check BindPlane Agent Logs

You can inspect the logs of your running BindPlane agent using either the Kubernetes terminal or directly from the BindPlane SaaS web interface:

### Method 1: From the Kubernetes Terminal (`kubectl`)
1. **Find the running BindPlane agent pod name:**
   ```bash
   kubectl get pods -A | grep -i -E "bindplane|observiq|agent"
   ```
2. **Stream the live logs:**
   ```bash
   kubectl logs -l app.kubernetes.io/name=bindplane-agent -n otel-demo -f
   ```
   *(Adjust `-l` label or namespace `-n` depending on the installation command you used).*

3. **What to look for in successful startup logs:**
   ```text
   connected to OpAMP server wss://opamp.observiq.com/v1/opamp
   received remote configuration from OpAMP server
   OTLP receiver started on 0.0.0.0:4317 / 0.0.0.0:4318
   ```

### Method 2: From the BindPlane SaaS UI ([app.observiq.com](https://app.observiq.com))
1. Go to **Agents** in the left navigation menu.
2. Click on your agent (`killercoda-otel-agent`) in the list.
3. Click the **Logs** tab or **View Recent Logs** button.
4. You can inspect live agent logs, connection status, and export errors directly in your browser without logging into Kubernetes!
