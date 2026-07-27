---
created: 2026-07-28
type: dev-docs
project: otel-lab
status: active
---

# [[AzureAKS]]: Dynatrace easyTrade on Azure Kubernetes Service (AKS)

## Overview
The `AzureAKS/` folder contains the Kubernetes deployment configuration and manifests for running the modern **[[easytrade]]** multi-tier financial trading application on **[[AzureAKS]] (Azure Kubernetes Service)** with **[[OpenTelemetry]]** and **[[Dynatrace]]** integration.

## Architecture
- **Application Workload (`[[easytrade]]`):** A cloud-native microservices architecture comprising .NET, Java, and Node.js backend services along with a React frontend and database tiers.
- **Platform:** Designed specifically for **[[AzureAKS]]** clusters, leveraging native Kubernetes routing, ingress controllers, and Azure Container Registry (ACR) deployments.
- **Telemetry Integration:** Services emit OpenTelemetry distributed traces and metrics which are routed through an in-cluster **[[OpenTelemetryCollector]]** or directly ingested into **[[Dynatrace]]**.

## Key Components & Subdirectories
- [easytrade/](file:///f:/otel-lab/AzureAKS/easytrade): The submodule/directory containing the application manifests, Docker Compose definitions (`[[compose.yaml]]`), and Kubernetes Helm charts (`[[helm/]]`).
- [easytrade/runDev.sh](file:///f:/otel-lab/AzureAKS/easytrade/runDev.sh): Helper script for launching local development builds.
