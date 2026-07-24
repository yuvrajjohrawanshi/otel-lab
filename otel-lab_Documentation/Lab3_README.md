---
created: 2026-07-24
type: dev-docs
project: otel-lab
status: active
---

# Lab 3: OpenTelemetry Operator & Demo Deployment

## Overview
This lab provides scripts to deploy the OpenTelemetry Operator for auto-instrumentation, a BindPlane-managed OpenTelemetry Collector (Agent), and the official OpenTelemetry Astronomy Shop Demo to a Kubernetes cluster.

The data flow architecture is:
`App (Auto-Instrumented) --> OTel Collector (BindPlane Agent) --> Dynatrace`

## Prerequisites
- A Kubernetes cluster.
- `kubectl` configured to communicate with your cluster.
- `helm` installed on your machine.
- A BindPlane OP Environment (URL and Secret Key).
- A Dynatrace environment URL and API token (configured within the BindPlane OP UI).

## Scripts

### 1. [[deploy.sh]]
This script automates the installation of the OpenTelemetry Operator and the BindPlane Agent.
- Installs `cert-manager`.
- Adds the OpenTelemetry and ObservIQ Helm repositories, and installs the OpenTelemetry Operator.
- Deploys the BindPlane Agent to manage the OpenTelemetry Collector's configuration remotely.
- Creates an `Instrumentation` resource that auto-instruments applications and forwards telemetry to the BindPlane Agent.

**Usage:**
Before running, you must edit `deploy.sh` and update:
- `BINDPLANE_URL`
- `BINDPLANE_SECRET_KEY`

### 2. [[deploy-demo.sh]]
This script deploys the OpenTelemetry Demo application using a local Helm chart (located in `opentelemetry-demo/charts/astroshop`).
- Creates a Kubernetes secret named `dt-credentials` containing your Dynatrace endpoint and token.
- Deploys the demo via Helm, ensuring it uses the provided secret for Dynatrace authentication instead of generating a new one.

**Usage:**
Before running, you must edit `deploy-demo.sh` and update:
- `DYNATRACE_URL`
- `DYNATRACE_TOKEN`

## Execution Steps
1. Update credentials in both scripts.
2. Run the operator deployment:
   ```bash
   ./deploy.sh
   ```
3. Run the demo deployment:
   ```bash
   ./deploy-demo.sh
   ```
4. Monitor the startup:
   ```bash
   kubectl get pods -n opentelemetry
   ```
