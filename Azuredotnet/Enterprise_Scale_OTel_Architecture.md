# Enterprise Scale OpenTelemetry Auto-Instrumentation

This document outlines the architectural approach for rolling out OpenTelemetry zero-code auto-instrumentation across thousands of Azure App Services (e.g., 3,000+ apps) efficiently, without the need to modify, rebuild, or manually upload files to each individual application.

---

## The Architecture: Shared Azure Files Mount

When scaling zero-code instrumentation, uploading the OpenTelemetry binaries (`net/`, `win-x64/`, etc.) to every single App Service via Kudu is inefficient and creates a massive maintenance burden when it's time to upgrade versions.

The solution is to use **Azure Files as a shared, read-only mount**.

```text
┌─────────────────────────────────────┐
│         Azure Files Share           │
│   (Storage Account: stotel...)      │
│                                     │
│   /otel-instrumentation/            │
│   ├── net/                          │
│   ├── win-x64/                      │
│   └── win-x86/                      │
└──────────┬──────────────────────────┘
           │  Mounted as C:\mounts\otel
           │  (read-only, shared)
           │
     ┌─────┼─────┬─────────┬──────────────┐
     │     │     │         │              │
  ┌──▼──┐ ┌▼───┐ ┌▼───┐  ┌─▼──┐      ┌───▼──┐
  │App 1│ │App 2│ │App 3│ │App 4│ ... │App 3K│
  └─────┘ └────┘ └────┘  └────┘      └──────┘
     All point OTEL_DOTNET_AUTO_HOME → C:\mounts\otel
```

### Benefits of this Approach
1. **Upload Once:** The OTel binaries are stored in one central storage account.
2. **Update Once:** To upgrade the OpenTelemetry version, you simply overwrite the files in the central share. All apps will pick up the new version on their next restart.
3. **No App Pollution:** The application's local disk (`C:\home\site\wwwroot` and `C:\home\site\otel`) remains completely untouched. You can safely delete any previously uploaded local instrumentation files.
4. **Read-Only Protection:** App Services mount this share, meaning application code cannot accidentally corrupt the shared binaries.

---

## Implementation Steps

### 1. Central Storage Creation
Create a standard Storage Account and a File Share, then upload the OpenTelemetry binaries (e.g., v1.10.0 for .NET 8 compatibility).

```bash
# Create storage account and share
az storage account create --name stotelshared --resource-group rg-otel-shared --location eastus --sku Standard_LRS
az storage share create --name otel-instrumentation --account-name stotelshared

# Upload binaries (assuming binaries are in local folder 'opentelemetry-dotnet-instrumentation-windows')
az storage file upload-batch --destination otel-instrumentation --source ./opentelemetry-dotnet-instrumentation-windows --account-name stotelshared
```

### 2. Mount and Configure App Services (Bulk Script)
You can automate the rollout across thousands of apps using a script that performs two actions on each app:
1. Mounts the Azure Files share to `/mounts/otel` (which maps to `C:\mounts\otel` on Windows App Services).
2. Sets the CLR Profiling environment variables to point to that new `C:\mounts\otel` path.

```powershell
# Get the storage access key
$key = az storage account keys list --account-name stotelshared --resource-group rg-otel-shared --query "[0].value" -o tsv

# Assume $apps is a list of your 3K web apps
foreach ($app in $apps) {
    
    # 1. Mount the shared drive
    az webapp config storage-account add `
      --resource-group $app.rg `
      --name $app.name `
      --custom-id otel-mount `
      --storage-type AzureFiles `
      --share-name otel-instrumentation `
      --account-name stotelshared `
      --access-key $key `
      --mount-path /mounts/otel

    # 2. Set environment variables
    az webapp config appsettings set `
      --resource-group $app.rg `
      --name $app.name `
      --settings `
        OTEL_DOTNET_AUTO_HOME="C:\mounts\otel" `
        CORECLR_ENABLE_PROFILING="1" `
        CORECLR_PROFILER="{918728DD-259F-4A6A-AC2B-B85E1B658318}" `
        CORECLR_PROFILER_PATH_32="C:\mounts\otel\win-x86\OpenTelemetry.AutoInstrumentation.Native.dll" `
        CORECLR_PROFILER_PATH_64="C:\mounts\otel\win-x64\OpenTelemetry.AutoInstrumentation.Native.dll" `
        DOTNET_STARTUP_HOOKS="C:\mounts\otel\net\OpenTelemetry.AutoInstrumentation.StartupHook.dll" `
        OTEL_EXPORTER_OTLP_ENDPOINT="http://<OTEL_COLLECTOR_URL>:4318" `
        OTEL_SERVICE_NAME=$app.name
}
```

*Note: For an enterprise rollout of this scale, it is highly recommended to point `OTEL_EXPORTER_OTLP_ENDPOINT` to an internal fleet of **OpenTelemetry Collectors** rather than sending 3,000 direct connections to a SaaS backend like Dynatrace.*

---

## Conceptual Addendum: The .NET Shared Store

When configuring OpenTelemetry auto-instrumentation, you may encounter legacy documentation mentioning the `DOTNET_SHARED_STORE` environment variable. 

### What is it?
Normally, .NET looks for assemblies (DLLs) in the application's local directory. Because zero-code instrumentation involves loading external assemblies (like `OpenTelemetry.dll`) that aren't in the app's folder, .NET needs to know where to find them. The `.NET Shared Store` (Runtime Package Store) was a mechanism that allowed you to pre-compile and share a set of assemblies across multiple applications on the same machine without copying them into every app's folder. 

### Why is it no longer needed?
In modern versions of OpenTelemetry .NET Auto-Instrumentation (v1.2.0+), the architecture was simplified using **.NET Startup Hooks** (`DOTNET_STARTUP_HOOKS`). 

The Startup Hook runs before your application's `Main()` method and injects an Assembly Resolution Handler into memory. This handler intercepts the runtime's requests for OpenTelemetry assemblies and points it directly to the `net` folder inside the `OTEL_DOTNET_AUTO_HOME` path. Because of this clever runtime injection, the bulky `DOTNET_SHARED_STORE` feature is completely obsolete for OpenTelemetry setups today.
