---
created: 2026-07-24
type: dev-docs
project: otel-lab
status: active
---

# Lab 3: easyTravel Auto-Instrumentation (KillerCoda)

## Overview
This lab deploys the legacy **Dynatrace easyTravel** application to a Kubernetes cluster. Because easyTravel does not include built-in OpenTelemetry, we use the **OpenTelemetry Operator** to automatically inject the OpenTelemetry Java agent into the easyTravel pods at runtime.

**Data Flow:**
`easyTravel App (Auto-Instrumented by Operator) --> OTel Collector`

## Architecture
The deployment includes:
- **easyTravel:** A classic multi-tier application (backend, frontend, mongodb, load generator).
- **OpenTelemetry Operator:** Watches for pods with the `instrumentation.opentelemetry.io/inject-java: "true"` annotation and injects the OTel agent.
- **OTel Collector:** Receives traces from the injected agents and logs them to the console (for debugging/verification).

## Environment
- **Kubernetes Platform:** [[KillerCoda]] (single-node playground with 4GB memory)
- **Note:** easyTravel uses fewer resources than the official OTel demo, making it much better suited for KillerCoda.

## Prerequisites
- A running Kubernetes cluster (KillerCoda)
- `kubectl` configured to communicate with your cluster
- `helm` (v3+) installed

## Deployment

Run the deployment script:
```bash
./deploy-easytravel.sh
```

This will:
1. Install `cert-manager`
2. Install the `OpenTelemetry Operator`
3. Deploy an OTel Collector and the `Instrumentation` auto-injection rules
4. Deploy the easyTravel Kubernetes manifests (which we've annotated for auto-injection)

> **Note:** On KillerCoda, pods may take 3–5 minutes to start due to image pulls on limited bandwidth.

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

Verify that the OpenTelemetry Operator successfully injected the Java agent into the pods:
```bash
kubectl describe pod -l app=backend -n otel-demo | grep opentelemetry-auto-instrumentation
```

Verify that traces are arriving at the Collector:
```bash
kubectl logs deployment/my-collector-collector -n otel-demo -f
```

## Cleanup
```bash
kubectl delete namespace otel-demo
kubectl delete namespace cert-manager
```
