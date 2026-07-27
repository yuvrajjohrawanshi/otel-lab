---
created: 2026-07-28
type: dev-docs
project: otel-lab
status: active
---

# [[AzureApp]]: Dynatrace easyTrade on Azure App Service

## Overview
The `AzureApp/` folder contains configurations and deployment scripts for hosting the **[[easytrade]]** microservices application on **[[AzureAppService]]** (Managed PaaS containers and web apps).

## Architecture & Features
- **PaaS Deployment:** Deploys `[[easytrade]]` without requiring a full Kubernetes cluster management plane by utilizing Azure App Service Linux Container support.
- **Telemetry Configuration:** Integrates Azure App Service application settings (`APPINSIGHTS_INSTRUMENTATIONKEY` / OTLP environment variables) to enable **[[OpenTelemetry]]** auto-instrumentation and export telemetry to **[[Dynatrace]]**.

## Key Components
- [easytrade/](file:///f:/otel-lab/AzureApp/easytrade): Contains Docker Compose and container definitions adapted for Azure App Service multi-container deployment.
