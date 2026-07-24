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

## Prerequisites
- A running Kubernetes cluster
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

## Accessing the Demo

**Frontend (Astronomy Shop):**
```bash
kubectl port-forward svc/otel-demo-frontend -n otel-demo 8080:8080
```
Then open http://localhost:8080

**Jaeger UI (Traces):**
```bash
kubectl port-forward svc/otel-demo-jaeger-query -n otel-demo 16686:16686
```
Then open http://localhost:16686

## Monitoring

```bash
kubectl get pods -n otel-demo
kubectl get svc -n otel-demo
```
