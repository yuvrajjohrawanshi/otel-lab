#!/bin/bash

# =============================================================================
# Lab 3: Deploy easyTravel with OpenTelemetry Auto-Instrumentation
#
# This script deploys the legacy Dynatrace easyTravel application.
# Because easyTravel has no built-in telemetry, we deploy the OpenTelemetry
# Operator to inject Java agents into the pods at runtime.
#
# Data Flow: App (Auto-Instrumented by Operator) --> OTel Collector
# =============================================================================

NAMESPACE="otel-demo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/easytravel-manifests"

echo "==> 1. Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> 2. Installing cert-manager (prerequisite for OpenTelemetry Operator)..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
echo "Waiting for cert-manager to be ready (this may take a minute)..."
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s

echo "==> 3. Installing OpenTelemetry Operator via Helm..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace $NAMESPACE \
  --set "manager.collectorImage.repository=otel/opentelemetry-collector-k8s"

echo "Waiting for OpenTelemetry Operator to be ready..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=opentelemetry-operator -n $NAMESPACE --timeout=300s

echo "Waiting an extra 15 seconds for the Operator webhook to become fully active..."
sleep 15

echo "==> 4. Deploying OTel Collector and Auto-Instrumentation rules..."
cat <<EOF | kubectl apply -f -
---
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: my-collector
  namespace: $NAMESPACE
spec:
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      debug:
        verbosity: detailed
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [debug]
        metrics:
          receivers: [otlp]
          exporters: [debug]
---
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: my-instrumentation
  namespace: $NAMESPACE
spec:
  exporter:
    endpoint: http://my-collector-collector.$NAMESPACE.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: always_on
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
EOF

echo "==> 5. Deploying easyTravel (auto-instrumented)..."
kubectl apply -f "$MANIFESTS_DIR" -n $NAMESPACE

echo "=========================================================================="
echo "Deployment Complete!"
echo ""
echo "Note: The OTel operator will automatically inject the Java agent into the"
echo "easyTravel pods as they start up."
echo ""
echo "To monitor pod startup on KillerCoda (may take 3-5 mins):"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
echo "To view easyTravel Frontend (once running):"
echo "  kubectl port-forward svc/angular-nginx-service -n $NAMESPACE 80:80 --address 0.0.0.0"
echo ""
echo "To view traces arriving at the Collector:"
echo "  kubectl logs -l app.kubernetes.io/name=my-collector-collector -n $NAMESPACE -f"
echo "=========================================================================="
