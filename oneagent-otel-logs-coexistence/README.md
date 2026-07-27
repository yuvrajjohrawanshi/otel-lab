# Lab 2: Coexistence of OneAgent and OpenTelemetry (Logs Only)

This lab demonstrates how to run **Dynatrace OneAgent (Full-Stack)** alongside an **OpenTelemetry Agent (Logs-Only)** on the same Linux VM. This is a common real-world architecture where OneAgent handles traces and metrics automatically without touching application code, but developers prefer OpenTelemetry, FluentBit, or similar log shippers to forward custom application and system logs.

## Architecture & Data Flow

```mermaid
flowchart LR
    subgraph "App VM (34.x.x.x)"
        App[Vanilla Node.js App]
        
        %% OneAgent Flow (Metrics/Traces)
        OneAgent[[Dynatrace OneAgent\n(Full-Stack)]]
        App -.Auto-injects.-> OneAgent
        
        %% OTel Flow (Logs only)
        SystemLogs[(System & App Logs\njournald / syslog)]
        OTelAgent[[OTel Agent\n(Reads Logs)]]
        OTelCollector[[OTel Collector Gateway]]
        
        SystemLogs --> OTelAgent
        OTelAgent --> OTelCollector
    end

    subgraph "ActiveGate VM (98.x.x.x)"
        AG[[Dynatrace ActiveGate]]
    end

    subgraph "Dynatrace SaaS"
        DT[(Dynatrace Env)]
    end

    %% Network links
    OneAgent == HTTPS:443 ==> AG
    OTelCollector == HTTP:9993 ==> AG
    AG == HTTPS:443 ==> DT

    classDef dt fill:#114e82,stroke:#fff,color:#fff
    classDef otel fill:#ffffff,stroke:#000,color:#000,stroke-width:2px,stroke-dasharray: 5 5
    
    class AG,DT,OneAgent dt;
    class OTelAgent,OTelCollector otel;
```

---

## Prerequisites

1.  **Dynatrace API Token:** Needs `openTelemetryTrace.ingest` (if expanding later), `metrics.ingest`, and `logs.ingest` scopes.
2.  **Dynatrace PaaS Token:** Needed to install the ActiveGate and OneAgent. (Generate in Settings -> Integration -> Platform as a Service).
3.  **SSH Client:** For accessing the AWS EC2 instances.

---

## Phase 1: Deploy Infrastructure via Terraform

Terraform will automatically boot two VMs and configure the network. Crucially, **Terraform now automatically installs and starts the vanilla Node.js application** on the App VM using a `cloud-init` user script (`setup_app.sh`). You do not need to install Node or configure the app yourself.

1. Open PowerShell and navigate to `lab2/terraform`:
   ```powershell
   cd f:\otel-lab\lab2\terraform
   ```
2. Set your IP in `terraform.tfvars`:
   ```hcl
   admin_cidr = "YOUR.IP.ADDRESS.HERE/32"
   ```
3. Initialize and deploy:
   ```powershell
   terraform init
   terraform apply -auto-approve
   ```
4. Note the output IP addresses and SSH commands.
5. Fix Windows SSH Key permissions (mandatory for Windows `OpenSSH`):
   ```powershell
   icacls.exe .\otel-lab2-key.pem /inheritance:r
   icacls.exe .\otel-lab2-key.pem /grant:r "$($env:USERNAME):(R)"
   ```

---

## Phase 2: Configure the Dynatrace ActiveGate

SSH into the ActiveGate VM. By acting as the central entry point, the ActiveGate ensures we're securely funneling both OneAgent traffic and OTel traffic through a single known host.

### 1. Install ActiveGate
Obtain the install command from Dynatrace UI -> **Deploy Dynatrace** -> **Set up ActiveGate** -> **Environment ActiveGate** -> **Linux**:

```bash
wget -O Dynatrace-ActiveGate-Linux-x86.sh "https://<YOUR_ENV>.live.dynatrace.com/api/v1/deployment/installer/gateway/unix/latest?Api-Token=<YOUR_PAAS_TOKEN>&arch=x86"
sudo /bin/sh Dynatrace-ActiveGate-Linux-x86.sh
```

### 2. Enable OTLP Generic Ingest
The ActiveGate needs to be informed it should accept OTLP data over port 9993.

```bash
sudo bash -c 'cat <<EOF >> /var/lib/dynatrace/gateway/config/custom.properties

[collector]
ListenPort = 9993

[http.client]
MSIgnoredModules =
EOF'

sudo systemctl restart dynatracegateway
```

---

## Phase 3: Instrument the App VM

SSH into the App VM! This VM already has the Node.js app running on port 3000 (installed by Terraform's `setup_app.sh`).

### Step A: Install Dynatrace OneAgent (Full-Stack Mode)
OneAgent will automatically hook into the Node.js process to capture metrics and traces without modifying a single line of code.

1. Go to Dynatrace UI -> **Deploy Dynatrace** -> **Start Installation** -> **Linux**.
2. Copy the wget command:
   ```bash
   wget -O Dynatrace-OneAgent-Linux-1.xx.sh "https://<YOUR_ENV>.live.dynatrace.com/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=<YOUR_PAAS_TOKEN>&arch=x86&flavor=default"
   ```
3. Run the installer in full-stack mode:
   ```bash
   sudo /bin/sh Dynatrace-OneAgent-Linux-1.xx.sh all=default
   ```
4. Once installed, **restart the Node.js app** to ensure OneAgent injects into it successfully:
   ```bash
   sudo systemctl restart otel-app
   ```
5. *(Optional) Curl your app to generate trace data:*
   ```bash
   curl http://localhost:3000/products
   ```

### Step B: Install OpenTelemetry (Logs Only Mode)
We will now deploy OTel purely to scrape `/var/log` and the `journald` database to test coexistence.

#### 1. Install OTel Contrib Binary
```bash
sudo yum install -y https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.104.0/otelcol-contrib_0.104.0_linux_amd64.rpm
```

#### 2. Deploy OTel Configs
These configs explicitly omit traces and metrics pipelines to prevent overlap.
Transfer the contents of `lab2/agent/otel-agent.yaml` into `/etc/otelcol/agent/otel-agent.yaml` and `lab2/collector/otel-collector.yaml` into `/etc/otelcol/collector/otel-collector.yaml` on the server.

You can also use the service definitions found in the root repository.

#### 3. Setup Auth and Start Services
Replace `<YOUR_API_TOKEN>`, `<ACTIVEGATE_PRIVATE_IP>`, and `<YOUR_ENV>`:

```bash
sudo bash -c 'cat <<EOF > /etc/otelcol/collector/otel-collector.env
DT_API_TOKEN=<YOUR_API_TOKEN>
DT_ACTIVEGATE_ENDPOINT=https://<ACTIVEGATE_PRIVATE_IP>:9993/e/<YOUR_ENV>/api/v2/otlp
EOF'

echo "COLLECTOR_ENDPOINT=grpc://127.0.0.1:4317" | sudo tee /etc/otelcol/agent/otel-agent.env

# Read permissions for logs
sudo usermod -aG systemd-journal otelcol-contrib

sudo systemctl daemon-reload
sudo systemctl enable --now otel-collector
sudo systemctl enable --now otel-agent
```

---

## Validation
1. Check the **Hosts** list in Dynatrace. Your App VM should appear perfectly monitored by Dynatrace OneAgent (Metrics & Traces).
2. Go to **Logs and Events** viewer in Dynatrace. You should see SSH attempts (`/var/log/secure`) and application logs tagged with the OTel pipeline.
3. No conflicts should exist since OneAgent is handling instrumentation and OTel is handling basic log scraping.

## Cleanup
Run `destroy.ps1` from the `terraform` directory locally to instantly wipe the VMs.
```powershell
# From the local terraform folder
.\destroy.ps1
```
