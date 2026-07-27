---
created: 2026-07-24
type: dev-docs
project: otel-lab
status: active
---

# [[easytravel-otel-autoinstrumentation]]: easyTravel Auto-Instrumentation on KillerCoda

## Overview
This lab deploys the legacy **Dynatrace easyTravel** application to a Kubernetes cluster and sends telemetry to **New Relic (US region)**.

### Permanent Reliable Architecture (Zero Operators / Zero Webhooks)
On resource-constrained environments like KillerCoda, Kubernetes Operators and admission webhooks (like `cert-manager` and `opentelemetry-operator`) frequently cause CNI routing flakes (`connect: no route to host`).

To provide a **permanent, 100% reliable solution**, this deployment completely removes all operators and webhooks:
- **OpenTelemetry Collector:** Deployed as a lightweight standard Kubernetes `Deployment`, `ConfigMap`, and `Service` (starts in 2 seconds with zero CRD dependencies).
- **Auto-Instrumentation:** Uses standard Kubernetes `initContainers` to inject the OpenTelemetry Java agent directly into the easyTravel JVM pods at startup without requiring mutating admission webhooks.

**Data Flow:**
`easyTravel App (initContainer auto-instrumented) --> OTel Collector --> New Relic (US) + Console Logs`

## Architecture
The deployment includes:
- **easyTravel:** A classic multi-tier application (`backend`, `angular-frontend`, `mongodb`, `loadgenerator`).
- **initContainer Agent Injection:** Each Java pod uses an init container (`autoinstrumentation-java`) that copies `/javaagent.jar` to a shared volume and sets `JAVA_TOOL_OPTIONS`.
- **OTel Collector (`otel-collector`):** Receives traces and metrics on port `4317` (gRPC) / `4318` (HTTP), prints to the console (`debug`), and forwards them to **New Relic (US region)** (`https://otlp.nr-data.net:443`).

## Environment
- **Kubernetes Platform:** [[KillerCoda]] (single-node playground with 4GB memory)
- **Note:** Zero operators means minimal memory consumption and zero webhook timeouts.

## Prerequisites
- A running Kubernetes cluster (KillerCoda)
- `kubectl` configured to communicate with your cluster

## Deployment

Run the deployment script:
```bash
./easytravel-otel-autoinstrumentation/deploy-easytravel.sh
```

This will:
1. Remove any leftover flaky mutating/validating webhooks from previous operator attempts.
2. Create namespace `otel-demo`.
3. Deploy the `otel-collector` ConfigMap, Service, and Deployment (configured for New Relic US ingest).
4. Deploy the auto-instrumented easyTravel application.

> **Note:** On KillerCoda, pods take ~2–4 minutes to start as container images are pulled.

## Accessing the Demo

### On KillerCoda
KillerCoda provides port access via its built-in traffic routing. After running `kubectl port-forward`, use the **Traffic / Ports** tab at the top of the KillerCoda terminal to access the forwarded port.

**easyTravel Frontend:**
```bash
kubectl port-forward svc/angular-nginx-service -n otel-demo 80:80 --address 0.0.0.0
```
Then access via KillerCoda's port `80` link.

### On a local cluster
```bash
kubectl port-forward svc/angular-nginx-service -n otel-demo 80:80
# Open http://localhost:80
```

## Monitoring & Verification

Watch the pods come up:
```bash
kubectl get pods -n otel-demo -w
```

Verify that traces are arriving at the Collector:
```bash
kubectl logs deployment/otel-collector -n otel-demo -f
```

## Cleanup
```bash
kubectl delete namespace otel-demo
```
