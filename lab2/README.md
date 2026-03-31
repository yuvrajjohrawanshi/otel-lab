# Lab 2 — VM Infrastructure Monitoring with OTel → ActiveGate → Dynatrace

## What We're Building

A native (no Docker) observability pipeline on a **Red Hat family** Linux VM:

```
[ RHEL/Rocky/AlmaLinux VM ]
  Standalone Node.js app (systemd)
  OTel Agent (systemd) — hostmetrics, syslog, app traces
         │
         │  gRPC (port 4317) — LAN traffic only
         ▼
[ OTel Collector Gateway VM ]
  Receives from all agents
  Converts cumulative → delta histograms
         │
         │  OTLP HTTP (port 9993)
         ▼
[ Dynatrace Environment ActiveGate ]
         │
         ▼
[ Dynatrace SaaS ]
  Traces → Services
  Metrics → Data Explorer / Notebooks
  Logs → Log Viewer
```

---

## Files in This Lab

```
lab2/
├── agent/
│   ├── otel-agent.yaml       ← OTel Agent config (runs on every VM)
│   ├── otel-agent.env        ← Env vars for the agent systemd service
│   └── otel-agent.service    ← systemd unit file for the agent
├── collector/
│   ├── otel-collector.yaml   ← Collector Gateway config
│   ├── otel-collector.env    ← Env vars (ActiveGate endpoint + API token)
│   └── otel-collector.service ← systemd unit file for the collector
└── app/
    ├── app.js                ← Node.js app with OTel SDK auto-instrumentation
    └── package.json          ← npm dependencies
```

---

## Prerequisites

### 1. ActiveGate — Enable OTLP Ingest

The Environment ActiveGate acts as the OTLP ingestion proxy into Dynatrace. By default, the generic OTLP endpoint on port `9993` **is enabled** on modern ActiveGate versions (v1.240+), but verify as follows:

```bash
# On the ActiveGate host — check if the generic ingest module is enabled
grep -i "MSIgnoredModules\|otlp\|genericIngest" /var/lib/dynatrace/gateway/config/custom.properties
```

If `genericIngest` does not appear or is disabled, add the following to `/var/lib/dynatrace/gateway/config/custom.properties` and restart:

```properties
# /var/lib/dynatrace/gateway/config/custom.properties
MSI_USE_BUILTIN_DEFAULT_JRE=1
```

```bash
sudo systemctl restart dynatracegateway
```

The ActiveGate OTLP endpoint format:
```
https://<ACTIVEGATE_FQDN_OR_IP>:9993/e/<ENVIRONMENT_ID>/api/v2/otlp
```

> **Finding your Environment ID:** In Dynatrace → top-right avatar menu → **Account Settings**. The ID is in your browser URL: `https://<ENV_ID>.live.dynatrace.com`

> **Note on routing:** When data flows through an ActiveGate, the authentication is still done by the **Dynatrace backend** — the ActiveGate merely relays the request. This means the API token you create in Dynatrace must have ingest scopes; the ActiveGate itself does not require any special configuration to verify the token.

---

### 2. API Token — Required Scopes

Create an API token at: **Dynatrace → Settings → Access Tokens → Generate token**

| Token Scope (UI Name) | Internal Scope ID | What it enables |
|---|---|---|
| Ingest OpenTelemetry traces | `openTelemetryTrace.ingest` | Sending spans/traces from the collector |
| Ingest metrics (v2) | `metrics.ingest` | Sending hostmetrics, app metrics |
| Ingest logs | `logs.ingest` | Sending syslog, journald, app logs |

> **These are the ONLY scopes needed.** The token does **not** need read scopes (`metrics.read`, `logs.read`, etc.) — those are only required for querying data back out of Dynatrace via the API. Ingest-only tokens follow the principle of least privilege.

> [!CAUTION]
> Never grant `WriteConfig`, `ReadConfig`, or any settings-management scopes to this token. It is an ingest-only credential and should be treated as such. Rotate it if it is ever exposed in logs.

Token naming suggestion: `otel-collector-ingest-<environment>` so it's clear what it's for and where it's used.

---

### 3. Firewall Rules

| From | To | Port | Protocol | Purpose |
|---|---|---|---|---|
| Monitored VM(s) | Collector VM | 4317 | TCP | Agent → Collector gRPC |
| Collector VM | ActiveGate VM | 9993 | TCP (HTTPS) | Collector → ActiveGate OTLP |
| ActiveGate VM | Dynatrace SaaS | 443 | TCP (HTTPS) | ActiveGate → DT backend |

---

## Step 1 — Install the OTel Collector Binary (on both VMs)

We install `otelcol-contrib` — the community distribution that includes all receivers including `hostmetrics`, `journald`, `k8sattributes`, etc.

```bash
# Download the latest otelcol-contrib RPM (check https://github.com/open-telemetry/opentelemetry-collector-releases/releases for latest)
OTEL_VERSION="0.96.0"
curl -LO "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_amd64.rpm"

# Install
sudo dnf install -y ./otelcol-contrib_${OTEL_VERSION}_linux_amd64.rpm

# Verify
otelcol-contrib --version
```

> The binary is installed to `/usr/local/bin/otelcol-contrib`. The RPM does **not** install any systemd service automatically — we define our own below.

---

## Step 2 — Create the Shared System User

Both the agent and collector should run as an unprivileged user:

```bash
sudo useradd --system --no-create-home --shell /sbin/nologin otelcol
```

> Access to `/run/log/journal` for the `journald` receiver requires adding this user to the `systemd-journal` group:
> ```bash
> sudo usermod -aG systemd-journal otelcol
> ```

---

## Step 3 — Set Up the OTel Agent (on the monitored VM)

### 3a. Create config directories
```bash
sudo mkdir -p /etc/otelcol/agent
```

### 3b. Copy config files
```bash
# From your cloned repo
sudo cp lab2/agent/otel-agent.yaml  /etc/otelcol/agent/otel-agent.yaml
sudo cp lab2/agent/otel-agent.env   /etc/otelcol/agent/otel-agent.env
sudo cp lab2/agent/otel-agent.service /etc/systemd/system/otel-agent.service
```

### 3c. Edit the env file with your Collector's IP
```bash
sudo vi /etc/otelcol/agent/otel-agent.env
```

Change `COLLECTOR_ENDPOINT` to your actual Collector VM IP:
```
COLLECTOR_ENDPOINT=grpc://10.0.0.5:4317
```

### 3d. Set permissions and start
```bash
sudo chown -R otelcol:otelcol /etc/otelcol/agent/
sudo chmod 640 /etc/otelcol/agent/otel-agent.env   # env file has no secrets but restrict anyway

sudo systemctl daemon-reload
sudo systemctl enable --now otel-agent

# Verify
sudo systemctl status otel-agent
sudo journalctl -u otel-agent -f
```

---

## Step 4 — Set Up the OTel Collector Gateway (on the Collector VM)

### 4a. Create config directories
```bash
sudo mkdir -p /etc/otelcol/collector
```

### 4b. Copy config files
```bash
sudo cp lab2/collector/otel-collector.yaml   /etc/otelcol/collector/otel-collector.yaml
sudo cp lab2/collector/otel-collector.env    /etc/otelcol/collector/otel-collector.env
sudo cp lab2/collector/otel-collector.service /etc/systemd/system/otel-collector.service
```

### 4c. Edit the env file — fill in your Dynatrace credentials
```bash
sudo vi /etc/otelcol/collector/otel-collector.env
```

```
# Format: https://<ACTIVEGATE_FQDN>:9993/e/<ENVIRONMENT_ID>/api/v2/otlp
DT_ACTIVEGATE_ENDPOINT=https://my-activegate.internal:9993/e/abc12345/api/v2/otlp
DT_API_TOKEN=dt0c01.your_token_here
```

> **Finding your Environment ID**: In Dynatrace → top-right menu → Account settings. The ID is in the URL: `https://<ENV_ID>.live.dynatrace.com`

### 4d. Set permissions and start
```bash
sudo chown -R otelcol:otelcol /etc/otelcol/collector/
sudo chmod 640 /etc/otelcol/collector/otel-collector.env   # contains secrets — restrict

sudo systemctl daemon-reload
sudo systemctl enable --now otel-collector

# Verify
sudo systemctl status otel-collector
sudo journalctl -u otel-collector -f
```

---

## Step 5 — Install Node.js and Run the App (on the monitored VM)

### 5a. Install Node.js 20 via NodeSource
```bash
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs
node --version   # should print v20.x.x
```

### 5b. Set up the app
```bash
sudo mkdir -p /opt/my-otel-app
sudo cp lab2/app/app.js       /opt/my-otel-app/
sudo cp lab2/app/package.json /opt/my-otel-app/

cd /opt/my-otel-app
sudo npm install --omit=dev
```

### 5c. Create the systemd unit for the app
```bash
sudo tee /etc/systemd/system/my-otel-app.service > /dev/null <<'EOF'
[Unit]
Description=My OTel Node.js App
After=network-online.target otel-agent.service
Wants=network-online.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/my-otel-app
ExecStart=/usr/bin/node app.js
Environment=OTEL_SERVICE_NAME=my-otel-app
Environment=OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317
Environment=PORT=3000
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now my-otel-app
sudo systemctl status my-otel-app
```

### 5d. Open the firewall port for external testing (optional)
```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

---

## Step 6 — Generate Test Traffic

```bash
# Hit all 3 endpoints to generate spans
curl http://localhost:3000/
curl http://localhost:3000/products
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 2, "quantity": 3}'
```

---

## Step 7 — Verify the Pipeline

### On the Agent VM — confirm data is flowing into the agent
```bash
sudo journalctl -u otel-agent --since "5 minutes ago" | grep -E "(Exporting|Sending|error)"
```

### On the Collector VM — confirm data is reaching the Gateway and being forwarded
```bash
sudo journalctl -u otel-collector --since "5 minutes ago" | grep -E "(Exporting|Sending|error)"
```

### A healthy log looks like:
```
otel-agent[1234]: 2024-03-28T17:00:00.000Z info  MetricsExporter {"kind": "exporter", "data_type": "metrics", "name": "otlp", "resource metrics": 1, "metrics": 12, "data points": 24}
otel-collector[5678]: 2024-03-28T17:00:05.000Z info  TracesExporter {"kind": "exporter", "data_type": "traces", "name": "otlphttp", "resource spans": 1, "spans": 3}
```

---

## Where to Find Data in Dynatrace

| Data | Where to look |
|---|---|
| App Traces (Express routes) | **Services** → `my-otel-app` → Distributed Traces |
| Node CPU / Memory | **Notebooks** → Metric query: `system.cpu.utilization` or `system.memory.usage` — split by `host.name` |
| Per-process CPU | **Notebooks** → `process.cpu.utilization` |
| Filesystem usage | **Notebooks** → `system.filesystem.utilization` — split by `host.name` |
| Syslog / Auth events | **Logs** → filter `host.name = <your-vm-hostname>` |

> **Tip — DQL query for CPU vitals in Notebooks:**
> ```dql
> fetch metrics
> | filter metric.key == "system.cpu.utilization"
> | summarize avg(value), by:{host.name, system.cpu.state}
> | sort avg(value) desc
> ```

---

## Troubleshooting

### Agent can't reach the Collector

```bash
# Test TCP connectivity from the VM to the Collector
nc -zv 10.0.0.5 4317

# Check firewall on the Collector VM
sudo firewall-cmd --list-ports
# If 4317 is not listed:
sudo firewall-cmd --permanent --add-port=4317/tcp
sudo firewall-cmd --reload
```

### Collector can't reach the ActiveGate

```bash
# Test HTTPS connectivity to the ActiveGate
curl -v https://your-activegate:9993/e/YOUR_ENV_ID/api/v2/otlp

# Common cause: port 9993 not open on the ActiveGate host's firewall
```

### `journald` receiver: permission denied

```bash
# The otelcol user needs to be in the systemd-journal group
sudo usermod -aG systemd-journal otelcol
sudo systemctl restart otel-agent
```

### Traces arrive but no spans in Dynatrace

Verify the OTel Agent service starts **before** the Node.js app (the `After=otel-agent.service` directive in the app unit handles this). If the app starts before the agent, the gRPC connection to `127.0.0.1:4317` fails silently on startup.

---

## Lab Outcome

| Component | Status |
|---|---|
| OTel Agent installed natively (otelcol-contrib RPM) | ⬜ |
| Agent collecting hostmetrics (CPU/Memory/Disk/Network) | ⬜ |
| Agent collecting syslog and auth logs via journald/filelog | ⬜ |
| Node.js app running as systemd service | ⬜ |
| App traces flowing: App → Agent → Collector | ⬜ |
| Collector forwarding to Dynatrace via ActiveGate | ⬜ |
| Data visible in Dynatrace Notebooks / Logs / Services | ⬜ |
