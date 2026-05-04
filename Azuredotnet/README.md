# Azure .NET App Service Deployment with OpenTelemetry Auto-Instrumentation

This lab documents the deployment of the [eShopOnWeb](https://github.com/dotnet-architecture/eShopOnWeb) ASP.NET Core 8 application to **Azure App Service (Windows, Code)** and configuring **zero-code OpenTelemetry auto-instrumentation** to export telemetry to Dynatrace.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Building the Application ZIP](#phase-1-building-the-application-zip)
3. [Phase 2: Manual Deployment to Azure App Service](#phase-2-manual-deployment-to-azure-app-service)
4. [Phase 3: OpenTelemetry Zero-Code Auto-Instrumentation](#phase-3-opentelemetry-zero-code-auto-instrumentation)
5. [Environment Variables Reference](#environment-variables-reference)
6. [Export Options](#export-options)
7. [Challenges Faced](#challenges-faced)

---

## Prerequisites

- **.NET 8 SDK** installed on your local machine ([Download](https://dotnet.microsoft.com/en-us/download/dotnet/8.0))
- **Azure CLI** installed and authenticated (`az login`)
- An **Azure Subscription** with permissions to create App Services
- A **Dynatrace SaaS** tenant (for telemetry export)

---

## Phase 1: Building the Application ZIP

The eShopOnWeb application needs to be published and packaged into a ZIP file for deployment.

### Step 1: Clone the eShopOnWeb repository

```powershell
cd F:\otel-lab\Azuredotnet
git clone https://github.com/dotnet-architecture/eShopOnWeb.git
cd eShopOnWeb
```

### Step 2: Publish the application

```powershell
dotnet publish src/Web/Web.csproj -c Release -o ./publish
```

This compiles the application in Release mode and outputs all deployable files to the `./publish` directory.

### Step 3: Create the deployment ZIP

```powershell
Compress-Archive -Path .\publish\* -DestinationPath .\eshoponweb.zip -Force
```

**Output:** `eshoponweb.zip` (~41 MB) at `F:\otel-lab\Azuredotnet\eShopOnWeb\eshoponweb.zip`

---

## Phase 2: Manual Deployment to Azure App Service

### Step 1: Create the Web App in Azure Portal

1. Go to [Azure Portal](https://portal.azure.com/).
2. Search for **App Services** → click **+ Create** → **Web App**.
3. Fill in the settings:

| Setting | Value |
|---|---|
| **Resource Group** | Create new → e.g. `rg-eshoponweb` |
| **Name** | e.g. `eshoponweb-yourname` (must be globally unique) |
| **Publish** | **Code** |
| **Runtime stack** | **.NET 8 (LTS)** |
| **Operating System** | **Windows** |
| **Region** | Choose an available region (e.g. `Central US`) |
| **Pricing Plan** | **Free F1** or **Basic B1** |

4. Click **Review + create** → **Create**. Wait for deployment to complete.

### Step 2: Configure Environment Variables

Since we are deploying without SQL databases (no Bicep provisioning), configure the app to use an in-memory database:

1. Go to your Web App → **Settings** → **Environment variables**.
2. Add two app settings:

| Name | Value |
|---|---|
| `ASPNETCORE_ENVIRONMENT` | `Development` |
| `UseOnlyInMemoryDatabase` | `true` |

3. Click **Apply** → **Confirm**.

### Step 3: Deploy the ZIP File via Kudu

1. In your Web App, go to **Development Tools** → **Advanced Tools** → click **Go →**.
2. In Kudu, click **Tools** → **Zip Push Deploy**.
3. Drag and drop `eshoponweb.zip` onto the page.
4. Wait for the upload and extraction to complete.

### Step 4: Verify

Go to your Web App **Overview** page and click the **Default domain** link (e.g. `https://eshoponweb-yourname.azurewebsites.net`). The app should load successfully.

---

## Phase 3: OpenTelemetry Zero-Code Auto-Instrumentation

This approach instruments the application **without modifying any source code**. It uses the .NET CLR Profiling API to dynamically inject OpenTelemetry at runtime.

### Step 1: Download the OTel .NET Auto-Instrumentation package

> **IMPORTANT:** Use version **v1.10.0** for .NET 8 compatibility. Version v1.15.0 ships `System.Diagnostics.DiagnosticSource v10.0` which is incompatible with .NET 8.

Download from: https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/tag/v1.10.0

File: `opentelemetry-dotnet-instrumentation-windows.zip`

### Step 2: Upload to Azure App Service

1. Open **Advanced Tools** (Kudu) → **Go →**.
2. Click **Debug console** → **CMD**.
3. Navigate to `C:\home\site`.
4. Create a folder named `otel`.
5. Extract and upload the contents of the downloaded ZIP into `C:\home\site\otel\`.

The resulting directory structure on Azure should be:

```
C:\home\site\otel\
├── LICENSE
├── VERSION
├── instrument.sh
├── net/
│   ├── OpenTelemetry.AutoInstrumentation.StartupHook.dll
│   ├── OpenTelemetry.AutoInstrumentation.dll
│   ├── net8.0/    ← .NET 8 specific instrumentation libraries
│   └── ...
├── netfx/         ← .NET Framework (not used)
├── win-x64/
│   └── OpenTelemetry.AutoInstrumentation.Native.dll  ← 64-bit native profiler
└── win-x86/
    └── OpenTelemetry.AutoInstrumentation.Native.dll  ← 32-bit native profiler
```

### Step 3: Configure Environment Variables

Go to your Web App → **Settings** → **Environment variables** and add all of the following:

#### CLR Profiler Variables

| Variable | Value | Explanation |
|---|---|---|
| `OTEL_DOTNET_AUTO_HOME` | `C:\home\site\otel` | Root directory of the OTel auto-instrumentation installation. Used by the agent to locate managed assemblies. |
| `CORECLR_ENABLE_PROFILING` | `1` | Enables the .NET CLR Profiling API. Required for the native profiler to attach to the process. |
| `CORECLR_PROFILER` | `{918728DD-259F-4A6A-AC2B-B85E1B658318}` | CLSID (unique identifier) of the OpenTelemetry .NET native profiler. The .NET runtime uses this to find and load the correct profiler DLL. |
| `CORECLR_PROFILER_PATH_32` | `C:\home\site\otel\win-x86\OpenTelemetry.AutoInstrumentation.Native.dll` | Path to the 32-bit native profiler DLL. Used when the App Service runs in 32-bit mode (default for Free F1 tier). |
| `CORECLR_PROFILER_PATH_64` | `C:\home\site\otel\win-x64\OpenTelemetry.AutoInstrumentation.Native.dll` | Path to the 64-bit native profiler DLL. Used when the App Service runs in 64-bit mode. |
| `DOTNET_STARTUP_HOOKS` | `C:\home\site\otel\net\OpenTelemetry.AutoInstrumentation.StartupHook.dll` | .NET Startup Hook DLL that gets loaded before `Program.Main()`. It bootstraps the managed OpenTelemetry SDK and registers all auto-instrumentation. |

#### Telemetry Export Variables

| Variable | Value | Explanation |
|---|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | *(See Export Options below)* | The URL where the OTLP exporter sends traces and metrics. |
| `OTEL_EXPORTER_OTLP_HEADERS` | *(See Export Options below)* | HTTP headers sent with every export request. Used for authentication (e.g., API tokens). |
| `OTEL_SERVICE_NAME` | `eShopOnWeb` | The logical name of your service as it appears in the observability backend. |

#### Logging & Debugging Variables (Optional)

| Variable | Value | Explanation |
|---|---|---|
| `OTEL_LOG_LEVEL` | `debug` | Log level for the OTel auto-instrumentation agent. Set to `debug` for troubleshooting, `info` for normal operation. |
| `OTEL_DOTNET_AUTO_LOG_DIRECTORY` | `C:\home\LogFiles\otel` | Directory where the agent writes its log files. Viewable via Kudu at `C:\home\LogFiles\otel`. |

### Step 4: Restart and Verify

Click **Apply** to save the environment variables. The App Service will restart automatically. Browse the app to generate traffic, then check your Dynatrace tenant for traces.

---

## Export Options

You have three options for exporting telemetry data to Dynatrace:

### Option 1: Direct to Dynatrace SaaS (Simplest)

The application sends telemetry directly to your Dynatrace environment's OTLP API endpoint.

| Variable | Value |
|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://<YOUR_DT_TENANT>.live.dynatrace.com/api/v2/otlp` |
| `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=Api-Token <YOUR_DT_API_TOKEN>` |

- **Pros:** No extra infrastructure required.
- **Cons:** App needs direct outbound internet access to Dynatrace.

### Option 2: Via OTel Collector (Most Flexible)

The app sends telemetry to an OpenTelemetry Collector. The Collector batches, transforms, and forwards it to Dynatrace.

| Variable | Value |
|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://<COLLECTOR_HOST>:4318` |
| `OTEL_EXPORTER_OTLP_HEADERS` | *(not needed — authentication handled at the Collector)* |

- **Pros:** Vendor-neutral app config. Collector can filter/enrich/transform data.
- **Cons:** Requires managing an OTel Collector instance.

### Option 3: Via ActiveGate (Best for Secure Networks)

The app sends telemetry to a Dynatrace ActiveGate which acts as a secure proxy.

| Variable | Value |
|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://<ACTIVEGATE_HOST>:9999/e/<TENANT_ID>/api/v2/otlp` |
| `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=Api-Token <YOUR_DT_API_TOKEN>` |

- **Pros:** Secure; only the ActiveGate needs external internet access.
- **Cons:** Requires a deployed and configured ActiveGate.

---

## Challenges Faced

### 1. Free Tier Quota Error (`SubscriptionIsOverQuotaForSku`)

**Problem:** When attempting to provision infrastructure via Bicep (`az deployment sub create`), Azure rejected the deployment with:
```
"code": "SubscriptionIsOverQuotaForSku"
"message": "Current Limit (Free VMs): 0"
```

**Cause:** The Azure subscription did not have quota allocation for Free (F1) tier App Services in the `eastus` region.

**Resolution:** Created the Web App manually through the Azure Portal UI, selecting a region and tier where quota was available.

---

### 2. HTTP Error 500.30 — ASP.NET Core App Failed to Start

**Problem:** After deploying the ZIP to App Service, the app crashed immediately with `HTTP Error 500.30`.

**Cause:** The app started in **Production** mode by default. In production mode, it attempts to connect to Azure Key Vault and Azure SQL databases (which were not provisioned since we skipped the Bicep deployment).

**Resolution:** Added two environment variables in App Service Configuration:
- `ASPNETCORE_ENVIRONMENT` = `Development`
- `UseOnlyInMemoryDatabase` = `true`

This forces the app to use an in-memory database instead of SQL Server.

---

### 3. Bicep Templates Configured for Linux

**Problem:** The original Bicep infrastructure templates (`appservice.bicep`, `appserviceplan.bicep`, `main.bicep`) were configured for Linux App Services.

**Cause:** The templates used `kind: 'app,linux'`, `reserved: true`, and `linuxFxVersion` — all Linux-specific settings.

**Resolution:** Modified the Bicep files to use Windows-compatible settings:
- `kind: 'app'` (Windows)
- `reserved: false` (Windows)
- `netFrameworkVersion: 'v8.0'` (replaces `linuxFxVersion`)
- `alwaysOn: false` (required for Free F1 tier)

---

### 4. .NET SDK Not in PATH

**Problem:** `dotnet` command was not recognized in PowerShell even though .NET 8 SDK was installed.

**Cause:** The SDK was installed at `C:\Program Files\dotnet\` but the current shell session's PATH was not updated after installation.

**Resolution:** Manually added dotnet to the session PATH:
```powershell
$env:PATH = "C:\Program Files\dotnet;" + $env:PATH
```

---

### 5. OTel Profiler Path Mismatch (32-bit vs 64-bit)

**Problem:** The OTel auto-instrumentation logged:
```
[Error] CLR profiler (32bit) is not found at '...\OpenTelemetry.AutoInstrumentation.StartupHook.dll'
```

**Cause:** Two issues:
1. `CORECLR_PROFILER_PATH` was incorrectly set to the managed `StartupHook.dll` instead of the native `OpenTelemetry.AutoInstrumentation.Native.dll`.
2. Azure Free (F1) App Services default to **32-bit** worker processes, so the runtime looked for the 32-bit profiler.

**Resolution:** Set both bitness paths explicitly:
- `CORECLR_PROFILER_PATH_32` → `...\win-x86\OpenTelemetry.AutoInstrumentation.Native.dll`
- `CORECLR_PROFILER_PATH_64` → `...\win-x64\OpenTelemetry.AutoInstrumentation.Native.dll`

---

### 6. OTel v1.15.0 Incompatible with .NET 8 (`DiagnosticSource v10.0`)

**Problem:** After fixing the profiler paths, the app crashed with:
```
System.IO.FileNotFoundException: Could not load file or assembly
'System.Diagnostics.DiagnosticSource, Version=10.0.0.0'
```

**Cause:** OTel .NET Auto-Instrumentation **v1.15.0** (latest at time of writing) ships `System.Diagnostics.DiagnosticSource` version 10.0, which is a .NET 10 assembly. This is fundamentally incompatible with a .NET 8 application runtime.

**Resolution:** Downgrade to OTel .NET Auto-Instrumentation **v1.10.0**, which is the last version with proper .NET 8 support. Download from:
https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/tag/v1.10.0

---

### 7. `OTEL_DOTNET_AUTO_HOME` Not Set

**Problem:** Even after fixing the profiler path, the agent logged:
```
[Error] Error when loading managed assemblies. Could not load file or assembly
'OpenTelemetry.AutoInstrumentation'
```

**Cause:** The `OTEL_DOTNET_AUTO_HOME` environment variable was not set. The native profiler uses this variable to locate the managed `net/OpenTelemetry.AutoInstrumentation.dll` assembly.

**Resolution:** Set `OTEL_DOTNET_AUTO_HOME` = `C:\home\site\otel` (the root directory containing `net/`, `win-x64/`, `win-x86/` subfolders).
