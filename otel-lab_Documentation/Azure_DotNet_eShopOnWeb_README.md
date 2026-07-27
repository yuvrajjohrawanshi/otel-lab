---
created: 2026-07-28
type: dev-docs
project: otel-lab
status: active
---

# [[azure-dotnet-eshoponweb]]: .NET eShopOnWeb Enterprise OpenTelemetry on Azure

## Overview
The `azure-dotnet-eshoponweb/` folder (formerly `Azuredotnet`) houses the enterprise reference architecture for instrumenting the classic Microsoft **[[eShopOnWeb]]** ASP.NET Core e-commerce application using the **[[OpenTelemetryDotNet]]** SDK and Windows/Linux instrumentation agents.

## Architecture
- **Application Workload (`[[eShopOnWeb]]`):** An ASP.NET Core MVC and Web API reference e-commerce application.
- **Instrumentation Modes:**
  1. **Automatic Windows Instrumentation:** Using the `opentelemetry-dotnet-instrumentation-windows` bundle to instrument IIS / .NET services automatically.
  2. **SDK Manual/Hosted Service Instrumentation:** Using OpenTelemetry ASP.NET Core, HttpClient, and SqlClient instrumentation packages.
- **Observability Stack:** Demonstrates how to configure ASP.NET Core trace propagation (`ActivitySource`), custom business metrics (`Meter`), and log export to enterprise observability platforms.

## Key Files & Directories
- [eShopOnWeb/](file:///f:/otel-lab/azure-dotnet-eshoponweb/eShopOnWeb): The core .NET e-commerce application source code.
- [Enterprise_Scale_OTel_Architecture.md](file:///f:/otel-lab/azure-dotnet-eshoponweb/Enterprise_Scale_OTel_Architecture.md): Detailed architectural whitepaper on enterprise-scale OpenTelemetry rollouts for .NET workloads.
- [opentelemetry-dotnet-instrumentation-windows/](file:///f:/otel-lab/azure-dotnet-eshoponweb/opentelemetry-dotnet-instrumentation-windows): Windows-specific MSI/script packages and auto-instrumentation hooks.
