---
created: 2026-07-24
type: dev-docs
project: otel-lab
status: active
---

# Lab 3: OpenTelemetry Demo Deployment

## Overview
This lab deploys the official **OpenTelemetry Astronomy Shop** demo application to a Kubernetes cluster. The demo comes with ~15 auto-instrumented microservices written in multiple languages (Go, Java, .NET, Node.js, Python, Rust, etc.) and a pre-configured OTel Collector.

**Data Flow:**
`App (Auto-Instrumented) --> OTel Collector`

## Architecture
The demo includes:
- **Microservices:** ~15 services (frontend, cart, checkout, payment, shipping, etc.)
- **OTel Collector:** Receives traces, metrics, and logs from all services
- **Jaeger:** Built-in trace visualization UI
- **Grafana:** Built-in dashboards for metrics

## Environment
- **Kubernetes Platform:** [[KillerCoda]] (single-node playground with limited CPU/memory)

## Prerequisites
- A running Kubernetes cluster (we use KillerCoda)
- `kubectl` configured to communicate with your cluster
- `helm` (v3+) installed

## Deployment

Run the deployment script:
```bash
./deploy.sh
```

This will:
1. Add the OpenTelemetry Helm repository
2. Create the `otel-demo` namespace
3. Deploy the full demo via Helm
4. Show a live pod monitoring dashboard until all pods are Running

> **Note:** On KillerCoda, pods may take 3–5 minutes to start due to image pulls on limited bandwidth. If pods get stuck in `Pending` or `OOMKilled`, resources may be insufficient — see the Troubleshooting section below.

## Accessing the Demo

### On KillerCoda
KillerCoda provides port access via its built-in traffic routing. After running `kubectl port-forward`, use the **Traffic / Ports** tab at the top of the KillerCoda terminal to access the forwarded port.

**Frontend (Astronomy Shop):**
```bash
kubectl port-forward svc/otel-demo-frontend -n otel-demo 8080:8080 --address 0.0.0.0
```
Then access via KillerCoda's port `8080` link.

**Jaeger UI (Traces):**
```bash
kubectl port-forward svc/otel-demo-jaeger-query -n otel-demo 16686:16686 --address 0.0.0.0
```
Then access via KillerCoda's port `16686` link.

### On a local cluster
```bash
kubectl port-forward svc/otel-demo-frontend -n otel-demo 8080:8080
# Open http://localhost:8080

kubectl port-forward svc/otel-demo-jaeger-query -n otel-demo 16686:16686
# Open http://localhost:16686
```

## Monitoring

```bash
kubectl get pods -n otel-demo
kubectl get svc -n otel-demo
kubectl logs -n otel-demo -l app.kubernetes.io/component=otelcol  # Collector logs
```

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Pods stuck in `Pending` | Insufficient CPU/memory on KillerCoda | Restart the KillerCoda environment |
| Pods in `OOMKilled` | Demo exceeds node memory | Reduce replicas or disable non-essential services |
| Pods in `ImagePullBackOff` | Rate-limited or slow pulls | Wait and retry — KillerCoda bandwidth is limited |

## Cleanup
```bash
helm uninstall otel-demo -n otel-demo
kubectl delete namespace otel-demo
```
