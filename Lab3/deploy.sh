#!/bin/bash

# =============================================================================
# Lab 3: Deploy OpenTelemetry Demo with OTel Collector
#
# This script deploys the official OpenTelemetry Astronomy Shop demo app.
# The demo comes with ~15 auto-instrumented microservices and an OTel Collector.
#
# Data Flow: App (Auto-Instrumented) --> OTel Collector
# =============================================================================

# Configuration
NAMESPACE="otel-demo"
RELEASE_NAME="otel-demo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> 1. Adding OpenTelemetry Helm repository..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

echo "==> 2. Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Deploying OpenTelemetry Demo (minimal mode for KillerCoda)..."
echo "    Using values: $SCRIPT_DIR/values-minimal.yaml"
echo ""

helm upgrade --install $RELEASE_NAME open-telemetry/opentelemetry-demo \
  --namespace $NAMESPACE \
  -f "$SCRIPT_DIR/values-minimal.yaml" \
  --debug 2>&1 | tail -30

if [ $? -ne 0 ]; then
  echo ""
  echo "ERROR: Helm install failed! Check the output above."
  echo "Try: helm upgrade --install $RELEASE_NAME open-telemetry/opentelemetry-demo --namespace $NAMESPACE -f $SCRIPT_DIR/values-minimal.yaml --debug"
  exit 1
fi

echo ""
echo "=========================================================================="
echo "Helm release created. Monitoring pod startup..."
echo "=========================================================================="
echo ""

# Monitor pod status until all are Running/Completed (or timeout after 10 min)
TIMEOUT=600
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
  echo ""
  echo "==> Pod Status (elapsed: ${ELAPSED}s / ${TIMEOUT}s timeout)"
  echo "--------------------------------------------------------------------------"
  kubectl get pods -n $NAMESPACE -o wide
  echo "--------------------------------------------------------------------------"

  TOTAL=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
  READY=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -cE "Running|Completed")

  echo ""
  echo "Ready: $READY / $TOTAL pods"

  if [ "$TOTAL" -gt 0 ] && [ "$READY" -eq "$TOTAL" ]; then
    echo ""
    echo "All pods are Running!"
    break
  fi

  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo ""
echo "=========================================================================="
echo "OpenTelemetry Demo Deployment Complete!"
echo ""
echo "The demo includes ~15 auto-instrumented microservices and an OTel Collector."
echo ""
echo "To access the demo frontend:"
echo "  kubectl port-forward svc/$RELEASE_NAME-frontend -n $NAMESPACE 8080:8080"
echo "  Then open http://localhost:8080"
echo ""
echo "To access Jaeger UI (traces):"
echo "  kubectl port-forward svc/$RELEASE_NAME-jaeger-query -n $NAMESPACE 16686:16686"
echo "  Then open http://localhost:16686"
echo "=========================================================================="
