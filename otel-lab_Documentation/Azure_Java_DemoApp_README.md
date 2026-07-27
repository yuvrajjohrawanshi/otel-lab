---
created: 2026-07-28
type: dev-docs
project: otel-lab
status: active
---

# [[azure-java-demoapp]]: Java Demo Application with OpenTelemetry on Azure

## Overview
The `azure-java-demoapp/` folder (formerly `azureappjava`) contains a Java Spring Boot enterprise demonstration application (`[[java-demoapp]]`) configured with **[[OpenTelemetryJava]]** auto-instrumentation for deployment on Azure cloud platforms.

## Architecture
- **Workload (`[[java-demoapp]]`):** A Spring Boot REST API service illustrating distributed tracing across HTTP endpoints, database calls, and messaging layers.
- **Auto-Instrumentation:** Uses the OpenTelemetry Java Agent (`-javaagent:opentelemetry-javaagent.jar`) to inject bytecode hooks into Servlet containers and JDBC drivers.
- **Cloud Integration:** Configured for Azure App Service / Azure Spring Apps with telemetry routed via standard OTLP endpoints.

## Key Subdirectories
- [java-demoapp/](file:///f:/otel-lab/azure-java-demoapp/java-demoapp): Spring Boot application source code, Maven build scripts (`pom.xml`), and container deployment configurations.
