# Lab 2 — Node.js App with OTel on Kubernetes → Dynatrace

## What We Built

A simple Node.js application with 3 HTTP endpoints, fully instrumented with the OpenTelemetry SDK, containerized with Docker, and deployed to a Kubernetes cluster. A separate OTel Collector runs alongside the app to receive its telemetry, enrich it with Kubernetes metadata, and forward everything to Dynatrace.

---

## Architecture

```
[ my-otel-app pod ]
  OTel SDK auto-instruments Express
  Sends traces + metrics to Collector
        │
        │  gRPC (port 4317)
        ▼
[ otel-collector pod ]
  Receives app telemetry (OTLP)
  Scrapes node/pod metrics (kubeletstats)
  Scrapes cluster metrics (k8s_cluster)
  Watches K8s events (k8s_events)
  Enriches with K8s labels (k8sattributes)
        │
        │  OTLP HTTP
        ▼
[ Dynatrace ]
  Traces → Services view
  Metrics → Metrics Explorer
  Events → Log Viewer
```

---

## Files Created

```
~/my-app/
├── app.js              → Node.js app with OTel SDK
├── package.json        → Dependencies
├── Dockerfile          → Container image definition
└── k8s/
    ├── namespace.yaml      → Namespace: my-app
    ├── deployment.yaml     → App deployment
    ├── service.yaml        → App service (ClusterIP)
    └── collector.yaml      → OTel Collector (6 K8s objects)
```

---

## File Contents

### `package.json`

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.2",
    "@opentelemetry/sdk-node": "^0.51.0",
    "@opentelemetry/auto-instrumentations-node": "^0.46.0",
    "@opentelemetry/exporter-trace-otlp-grpc": "^0.51.0",
    "@opentelemetry/exporter-metrics-otlp-grpc": "^0.51.0"
  }
}
```

---

### `app.js`

```js
'use strict';

// OTel MUST be initialized before Express
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
    }),
    exportIntervalMillis: 10000,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

const express = require('express');
const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'Hello from my app', status: 'ok' });
});

app.get('/products', (req, res) => {
  const products = [
    { id: 1, name: 'Telescope', price: 299.99 },
    { id: 2, name: 'Star Map',  price: 19.99  },
    { id: 3, name: 'Moon Lamp', price: 49.99  },
  ];
  res.json({ products, count: products.length });
});

app.post('/orders', (req, res) => {
  const { productId, quantity } = req.body;
  const order = {
    orderId:   `ORD-${Date.now()}`,
    productId: productId || 1,
    quantity:  quantity  || 1,
    status:    'confirmed',
    createdAt: new Date().toISOString(),
  };
  res.status(201).json({ order });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`App listening on port ${PORT}`));
```

> **Critical**: `sdk.start()` must run before `require('express')`. The OTel SDK patches the Node.js `http` module. If Express loads first, the patch has nothing to intercept and auto-instrumentation produces no spans.

---

### `Dockerfile`

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev

FROM node:20-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY app.js .
COPY package.json .
EXPOSE 3000
CMD ["node", "app.js"]
```

Two-stage build: stage 1 installs dependencies, stage 2 copies only what's needed. Keeps the final image small (~180MB vs ~1GB for full Ubuntu).

---

### `k8s/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
```

---

### `k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-otel-app
  namespace: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-otel-app
  template:
    metadata:
      labels:
        app: my-otel-app
    spec:
      containers:
        - name: my-otel-app
          image: my-otel-app:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 3000
          env:
            - name: OTEL_SERVICE_NAME
              value: "my-otel-app"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4317"
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
```

> `imagePullPolicy: Never` — required when using a locally built image on KillerCoda. Without it, K8s tries to pull from Docker Hub and fails.

---

### `k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-otel-app
  namespace: my-app
spec:
  selector:
    app: my-otel-app
  ports:
    - name: http
      port: 80
      targetPort: 3000
  type: ClusterIP
```

---

### `k8s/collector.yaml` (final corrected version)

Contains 6 objects: ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, Deployment, Service.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: my-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - nodes/stats
      - nodes/proxy
      - pods
      - events
      - namespaces
      - services
      - endpoints
      - resourcequotas
      - replicationcontrollers
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-collector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-collector
subjects:
  - kind: ServiceAccount
    name: otel-collector
    namespace: my-app
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: my-app
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      kubeletstats:
        collection_interval: 30s
        auth_type: serviceAccount
        endpoint: "https://${env:K8S_NODE_IP}:10250"   # Use IP, not hostname
        insecure_skip_verify: true
        metric_groups:
          - node
          - pod
          - container

      k8s_cluster:
        collection_interval: 30s
        auth_type: serviceAccount
        node_conditions_to_report: [Ready, MemoryPressure, DiskPressure]

      k8s_events:
        auth_type: serviceAccount
        namespaces: [my-app, default]

    processors:
      batch:
        timeout: 5s
      k8sattributes:
        auth_type: serviceAccount
        passthrough: false
        extract:
          metadata:
            - k8s.pod.name
            - k8s.pod.uid
            - k8s.deployment.name
            - k8s.namespace.name
            - k8s.node.name
      cumulativetodelta:   # Converts cumulative histograms → delta for Dynatrace

    exporters:
      otlphttp:
        endpoint: "${env:DT_ENDPOINT}"
        headers:
          Authorization: "Api-Token ${env:DT_API_TOKEN}"
      debug:
        verbosity: basic

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [k8sattributes, batch]
          exporters: [otlphttp, debug]
        metrics:
          receivers: [otlp, kubeletstats, k8s_cluster]
          processors: [cumulativetodelta, k8sattributes, batch]
          exporters: [otlphttp, debug]
        logs:
          receivers: [k8s_events]
          processors: [k8sattributes, batch]
          exporters: [otlphttp, debug]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: otel-collector
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.96.0
          args: ["--config=/conf/config.yaml"]
          env:
            - name: DT_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: dynatrace-otelcol-dt-api-credentials
                  key: endpoint           # actual key name in the secret
            - name: DT_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: dynatrace-otelcol-dt-api-credentials
                  key: token              # actual key name in the secret
            - name: K8S_NODE_IP           # node IP for kubeletstats
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
          ports:
            - containerPort: 4317
            - containerPort: 4318
          volumeMounts:
            - name: config
              mountPath: /conf
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: my-app
spec:
  selector:
    app: otel-collector
  ports:
    - name: grpc
      port: 4317
      targetPort: 4317
    - name: http
      port: 4318
      targetPort: 4318
  type: ClusterIP
```

---

## Deploy Sequence

```bash
# 1. Build Docker image
cd ~/my-app
docker build -t my-otel-app:latest .

# 2. Import into containerd (KillerCoda uses containerd, not Docker directly)
docker save my-otel-app:latest | ctr -n k8s.io images import -

# 3. Verify containerd can see it
ctr -n k8s.io images ls | grep my-otel-app

# 4. Create namespace and credentials
kubectl apply -f k8s/namespace.yaml

kubectl create secret generic dynatrace-otelcol-dt-api-credentials \
  --namespace my-app \
  --from-literal=DT_ENDPOINT='https://YOUR_ENV.live.dynatrace.com/api/v2/otlp' \
  --from-literal=DT_API_TOKEN='YOUR_TOKEN'

# 5. Deploy everything
kubectl apply -f k8s/collector.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 6. Verify
kubectl get pods -n my-app -w
```

---

## Testing the App

```bash
# Port-forward to reach the app from outside the cluster
kubectl port-forward -n my-app svc/my-otel-app 8080:80 &

curl http://localhost:8080/
curl http://localhost:8080/products
curl -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{"productId": 2, "quantity": 3}'
```

---

## Where to Find Data in Dynatrace

| Data | Dynatrace Path |
|---|---|
| App traces | Services → `my-otel-app` → Distributed Traces |
| Node CPU/memory | Metrics Explorer → search `k8s.node.cpu` |
| Pod metrics | Metrics Explorer → search `k8s.pod` |
| K8s events (pod restarts) | Logs → filter `k8s.namespace.name = my-app` |
| Cluster overview | Infrastructure → Kubernetes |

> **Note**: The classic "Hosts" view under Infrastructure is **OneAgent-only**. OTel-sourced host metrics appear in Metrics Explorer, not the Hosts dashboard.

---

---

# Issues Encountered & Solutions

---

## Issue 1 — `CreateContainerConfigError`: Secret Key Names Mismatch

### Symptom
```
otel-collector pod stuck in CreateContainerConfigError

kubectl describe pod → Events:
  Error: couldn't find key DT_ENDPOINT in Secret my-app/dynatrace-otelcol-dt-api-credentials
```

### Root Cause
The Kubernetes Secret was created with key names `endpoint` and `token`. The collector Deployment referenced `DT_ENDPOINT` and `DT_API_TOKEN` — names that don't exist in the secret.

```
Secret has:           Deployment referenced:
  endpoint      ≠       DT_ENDPOINT    ← mismatch
  token         ≠       DT_API_TOKEN   ← mismatch
```

When a pod references a non-existent key in a Secret, Kubernetes cannot assemble the container configuration at all. The pod never even starts.

### How to Diagnose
```bash
kubectl describe secret dynatrace-otelcol-dt-api-credentials -n my-app
# Shows actual key names under "Data ===" section
```

### Fix Applied
Patched the Deployment to use the correct key names:
```bash
kubectl patch deployment otel-collector -n my-app --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/key","value":"endpoint"},
  {"op":"replace","path":"/spec/template/spec/containers/0/env/1/valueFrom/secretKeyRef/key","value":"token"}
]'
```

### Prevention
Always verify secret key names before referencing them:
```bash
kubectl describe secret <name> -n <namespace>
```
Or create the secret with the exact key names your manifests expect.

---

## Issue 2 — `kubeletstats`: Node Hostname Not Resolvable From Pod

### Symptom
```
error   kubeletstatsreceiver/scraper.go:77   call to /stats/summary endpoint failed
  "error": "Get \"https://controlplane:10250/stats/summary\": 
   dial tcp: lookup controlplane on 10.96.0.10:53: no such host"
```
Node/pod metrics completely absent. No `k8s.node.*` or `k8s.pod.*` metrics in Dynatrace.

### Root Cause
The kubeletstats receiver was configured to use `${env:K8S_NODE_NAME}` (the node's hostname, e.g. `controlplane`) in the endpoint URL. While the node name is valid for `kubectl`, it is **not a DNS-resolvable hostname inside pod network**.

A pod can resolve `kubernetes.default.svc.cluster.local` (the API server) and other services, but bare hostnames like `controlplane` are not registered in the cluster's internal DNS.

```
kubeletstats endpoint: https://controlplane:10250
                                ↑
                   Not in cluster DNS → lookup fails
```

### Fix
Use `status.hostIP` (the node's actual IP address) instead of `spec.nodeName` (the hostname).

**Deployment patch** — add a new env var with the node IP:
```bash
kubectl patch deployment otel-collector -n my-app --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{
    "name":"K8S_NODE_IP",
    "valueFrom":{"fieldRef":{"fieldPath":"status.hostIP"}}
  }}
]'
```

**ConfigMap change** — use the IP in the endpoint:
```yaml
# Before (broken):
kubeletstats:
  endpoint: "https://${env:K8S_NODE_NAME}:10250"

# After (fixed):
kubeletstats:
  endpoint: "https://${env:K8S_NODE_IP}:10250"
```

### Why This Works
`status.hostIP` is the routable IP of the node as seen by the pod network. The kubelet listens on this IP on port 10250. An IP address needs no DNS resolution — the TCP connection goes directly.

---

## Issue 3 — Dynatrace Rejects Cumulative Histogram Metrics (400 Error)

### Symptom
```
error   exporterhelper/queue_sender.go:97   Exporting failed. Dropping data.
  "error": "Permanent error: request to https://xxx.live.dynatrace.com/api/v2/otlp/v1/metrics 
   responded with HTTP Status Code 400,
   Message=All metric data points were rejected.
   Errors: Unsupported metric: 'http.server.duration' - 
   Reason: UNSUPPORTED_METRIC_TYPE_CUMULATIVE_HISTOGRAM"
```

### Root Cause
OpenTelemetry's HTTP auto-instrumentation emits `http.server.duration` as a **cumulative histogram** by default. This is the OTel SDK's default temporality.

Dynatrace's OTLP ingest endpoint **does not support cumulative histograms**. It only accepts:
- Gauges
- Sums (both delta and cumulative)
- Delta histograms

```
OTel SDK emits:  cumulative histogram  (default)
Dynatrace wants: delta histogram        (or no histogram)
```

### Fix
Add the `cumulativetodelta` processor to the metrics pipeline in the OTel Collector. It converts cumulative histograms to delta before they are exported.

```yaml
processors:
  cumulativetodelta:   # no config needed, applies to all histograms

service:
  pipelines:
    metrics:
      receivers: [otlp, kubeletstats, k8s_cluster]
      processors: [cumulativetodelta, k8sattributes, batch]   # must be first
      exporters: [otlphttp, debug]
```

> **Order matters**: `cumulativetodelta` must come before `batch` in the processor chain, otherwise batch may flush data before conversion.

### Alternative Fix (app-side)
Set this env var on the app pod to make the SDK emit delta directly:
```yaml
- name: OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE
  value: "delta"
```
This avoids the conversion step entirely but requires changing the app deployment.

---

## Issue 4 — RBAC Warnings: Missing Resources in ClusterRole

### Symptom
```
W reflector.go:539  failed to list *v1.ReplicationController: 
  replicationcontrollers is forbidden: User "system:serviceaccount:my-app:otel-collector" 
  cannot list resource "replicationcontrollers"

W reflector.go:539  failed to list *v2.HorizontalPodAutoscaler: 
  horizontalpodautoscalers.autoscaling is forbidden
```

### Root Cause
The `k8s_cluster` receiver in the OTel Collector tries to list additional resource types beyond what was granted in the ClusterRole. Specifically it queries `replicationcontrollers` (core API group) and `horizontalpodautoscalers` (autoscaling API group) — neither was in the original ClusterRole.

These warnings don't crash the collector, but those resource types are excluded from cluster metrics.

### Fix
Add the missing resources to the ClusterRole:
```bash
kubectl patch clusterrole otel-collector --type='json' -p='[
  {"op":"add","path":"/rules/0/resources/-","value":"replicationcontrollers"},
  {"op":"add","path":"/rules/-","value":{
    "apiGroups":["autoscaling"],
    "resources":["horizontalpodautoscalers"],
    "verbs":["get","list","watch"]
  }}
]'
```

Or include them in the ClusterRole from the start (see corrected `collector.yaml` above).

---

## Issue 5 — Conceptual: Classic "Hosts" View Is OneAgent-Only

### Symptom
After the collector was running and traces were flowing, the user could see their service in Smartscape but could not find it under **Infrastructure → Hosts** in Dynatrace.

### Explanation
This is by design, not a bug.

| Monitoring approach | Where data appears |
|---|---|
| Dynatrace OneAgent (installed on host) | Infrastructure → Hosts, Smartscape as a Host entity |
| OpenTelemetry Collector with kubeletstats | Metrics Explorer (`k8s.node.*`), no Host entity created |

The classic "Hosts" dashboard in Dynatrace is populated by the **OneAgent** which runs as a process on the host, monitors at the OS level, and auto-discovers everything. The OTel Collector sends raw metrics — Dynatrace ingests them as metrics but does not synthesize a "Host" entity from them unless the OneAgent is present.

### Where to Find OTel-Sourced Host Metrics
```
Menu → Observe and explore → Metrics
Search: k8s.node.cpu.usage   ← node CPU
Search: k8s.node.memory      ← node memory
Search: k8s.pod.cpu          ← per-pod CPU
```

### Key Takeaway
OTel and OneAgent are complementary, not interchangeable:
- **OTel**: Portable, code-level instrumentation, traces and custom metrics
- **OneAgent**: Full host + process + network monitoring with zero code changes

In production environments, you often run both.

---

## Lab Outcome

| Component | Status |
|---|---|
| App deployed to K8s | ✅ |
| OTel SDK auto-instrumenting Express | ✅ |
| Traces reaching Dynatrace | ✅ |
| Collector running | ✅ |
| App metrics (histogram fix applied) | ✅ |
| kubeletstats node metrics (fix applied) | ✅ |
| k8s_cluster metrics | ✅ |
| k8s_events | ✅ |
