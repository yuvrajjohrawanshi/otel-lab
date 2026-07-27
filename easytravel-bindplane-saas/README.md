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

---

## Accessing the Demo (KillerCoda)

**Port-Forward easyTravel Frontend (Port 80):**
```bash
kubectl port-forward svc/angular-nginx-service -n otel-demo 80:80 --address 0.0.0.0
```
*(Then click the **Traffic -> Port 80** tab at the top of your KillerCoda terminal).*

---

## Checking BindPlane Agent Logs

**Stream agent logs via `kubectl`:**
```bash
kubectl logs -l app.kubernetes.io/name=bindplane-node-agent -n bindplane-agent -f
```
*(Or simply click the **Logs** tab on **[app.observiq.com](https://app.observiq.com)**).*

---

For comprehensive documentation, architecture diagrams, and troubleshooting, see:
- **[../otel-lab_Documentation/BindPlane_Lab_README.md](../otel-lab_Documentation/BindPlane_Lab_README.md)**
- **[../otel-lab_Documentation/BindPlane_Integration.md](../otel-lab_Documentation/BindPlane_Integration.md)**
