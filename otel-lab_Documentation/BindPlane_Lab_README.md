---
created: 2026-07-27
type: dev-docs
project: otel-lab
status: active
---

# [[BindPlane]] SaaS Lab (`BindPlane-Lab/`)

## Overview
This lab demonstrates how to integrate **[[BindPlane]] SaaS (observIQ Cloud)** as your enterprise observability control plane with an auto-instrumented application (`[[backend]]`, `[[angular-frontend]]`, `[[loadgenerator]]`).

Instead of hosting a standalone OpenTelemetry Collector configured by manual Kubernetes ConfigMaps, this lab routes telemetry to a **BindPlane SaaS Agent** managed 100% from your web browser.

---

## Architecture

```text
                                   +-------------------------+
                                   |   BindPlane SaaS Web    |
                                   |   (app.observiq.com)    |
                                   +------------+------------+
                                                |
                                                | (OpAMP Protocol / WebSockets)
                                                v
Auto-Instrumented easyTravel Pods ---> BindPlane Agent (K8s) ---> New Relic (US)
  (backend, angular-frontend)
```

1. **Auto-Instrumented easyTravel Pods:** Use OpenTelemetry Java auto-instrumentation (`initContainer` + `-javaagent:/otel-auto-instrumentation/javaagent.jar`).
2. **OTLP Endpoint:** All pods point their `OTEL_EXPORTER_OTLP_ENDPOINT` to `http://bindplane-node-agent.bindplane-agent.svc.cluster.local:4318`.
3. **BindPlane SaaS Agent:** Deployed directly from the [app.observiq.com](https://app.observiq.com) UI into your cluster.

---

## Lab Execution Instructions

### 1. Deploy Auto-Instrumented easyTravel
From the `BindPlane-Lab/` directory, run:
```bash
cd BindPlane-Lab/
chmod +x deploy-easytravel-bindplane.sh
./deploy-easytravel-bindplane.sh
```

### 2. Deploy the Agent from BindPlane SaaS UI
1. Log in to your tenant at **[app.observiq.com](https://app.observiq.com)**.
2. Click **Agents -> Install Agent -> Kubernetes**.
3. Copy the generated `kubectl apply` command and execute it in your terminal.

### 3. Attach a Pipeline Configuration
1. In BindPlane SaaS, go to **Configurations -> Create Configuration**.
2. Add an **OTLP Source** (ports `4317` & `4318`).
3. Add a **New Relic Destination** with your License Key (`3f25decf...NRAL`).
4. Attach this configuration to your running `killercoda-otel-agent`.

---

## Verification & Monitoring
- **Check easyTravel pods:** `kubectl get pods -n otel-demo -w`
- **Check BindPlane agent pods:** `kubectl get pods -n bindplane-agent -w`
- **Check agent logs:** `kubectl logs -l app.kubernetes.io/name=bindplane-node-agent -n bindplane-agent -f`
