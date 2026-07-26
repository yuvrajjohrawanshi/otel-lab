#!/bin/bash

# =============================================================================
# Lab 3: Deploy easyTravel with OpenTelemetry Auto-Instrumentation
#
# PERMANENT RELIABLE ARCHITECTURE (Zero Operators / Zero Webhooks):
# Instead of flaky Kubernetes Operators and mutating webhooks (which fail on
# KillerCoda's CNI with "no route to host"), this script deploys:
# 1. A standard Kubernetes Deployment + ConfigMap for the OpenTelemetry Collector.
# 2. easyTravel pods with an initContainer that injects the OpenTelemetry Java
#    agent directly into the JVM without needing an operator.
#
# Data Flow: easyTravel App --> OTel Collector --> New Relic (US) + Console Logs
# =============================================================================

NAMESPACE="otel-demo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/easytravel-manifests"

echo "==> 1. Cleaning up any leftover flaky operator installations..."
kubectl delete mutatingwebhookconfigurations --all --ignore-not-found=true 2>/dev/null
kubectl delete validatingwebhookconfigurations --all --ignore-not-found=true 2>/dev/null
kubectl delete namespace cert-manager --ignore-not-found=true 2>/dev/null

echo "==> 2. Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Deploying OpenTelemetry Collector (ConfigMap + Deployment + Service)..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: $NAMESPACE
data:
  otel-collector-config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      batch: {}
    exporters:
      debug:
        verbosity: detailed
      otlphttp/newrelic:
        endpoint: "https://otlp.nr-data.net:443"
        headers:
          api-key: "3f25decf1051541f1ff3ca603353f3b578beNRAL"
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [debug, otlphttp/newrelic]
        metrics:
          receivers: [otlp]
          processors: [batch]
          exporters: [debug, otlphttp/newrelic]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: $NAMESPACE
  labels:
    app: otel-collector
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
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:latest
          args:
            - "--config=/etc/otel-collector-config.yaml"
          ports:
            - containerPort: 4317
              name: grpc
            - containerPort: 4318
              name: http
          resources:
            requests:
              memory: "100Mi"
              cpu: "100m"
            limits:
              memory: "300Mi"
              cpu: "500m"
          volumeMounts:
            - name: config-volume
              mountPath: /etc/otel-collector-config.yaml
              subPath: otel-collector-config.yaml
      volumes:
        - name: config-volume
          configMap:
            name: otel-collector-config
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: $NAMESPACE
spec:
  ports:
    - name: grpc
      port: 4317
      targetPort: 4317
    - name: http
      port: 4318
      targetPort: 4318
  selector:
    app: otel-collector
  type: ClusterIP
EOF

echo "==> 4. Deploying easyTravel (with initContainer Auto-Instrumentation)..."
kubectl apply -f "$MANIFESTS_DIR" -n $NAMESPACE

echo "=========================================================================="
echo "Deployment Complete! (Zero Operators / Zero Webhooks)"
echo ""
echo "To monitor pod startup on KillerCoda (may take 2-4 mins):"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
echo "To view easyTravel Frontend (once running):"
echo "  kubectl port-forward svc/angular-nginx-service -n $NAMESPACE 80:80 --address 0.0.0.0"
echo ""
echo "To view traces arriving at the Collector:"
echo "  kubectl logs deployment/otel-collector -n $NAMESPACE -f"
echo "=========================================================================="
