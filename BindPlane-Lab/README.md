# BindPlane SaaS Observability Lab (`BindPlane-Lab/`)

This directory contains the auto-instrumented Dynatrace **easyTravel** application configured specifically for integration with **BindPlane SaaS (observIQ Cloud)**.

## Quick Start

1. **Deploy easyTravel:**
   ```bash
   chmod +x deploy-easytravel-bindplane.sh
   ./deploy-easytravel-bindplane.sh
   ```
2. **Deploy the BindPlane Agent from the UI:**
   - Log in to **[app.observiq.com](https://app.observiq.com)**.
   - Go to **Agents -> Install Agent -> Kubernetes** and run the generated command in your terminal.
3. **Configure the Pipeline:**
   - Create a configuration in BindPlane SaaS with an **OTLP Source** (ports `4317`/`4318`) and a **New Relic Destination**.

For comprehensive documentation, architecture diagrams, and troubleshooting, see:
- **[../otel-lab_Documentation/BindPlane_Lab_README.md](../otel-lab_Documentation/BindPlane_Lab_README.md)**
- **[../otel-lab_Documentation/BindPlane_Integration.md](../otel-lab_Documentation/BindPlane_Integration.md)**
