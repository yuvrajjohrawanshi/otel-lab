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

echo "==> 1. Adding OpenTelemetry Helm repository..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

echo "==> 2. Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Deploying OpenTelemetry Demo..."
helm upgrade --install $RELEASE_NAME open-telemetry/opentelemetry-demo \
  --namespace $NAMESPACE

echo "=========================================================================="
echo "OpenTelemetry Demo Deployment Complete!"
echo ""
echo "The demo includes ~15 auto-instrumented microservices and an OTel Collector."
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE           # Check pod status"
echo "  kubectl get svc -n $NAMESPACE             # List services"
echo ""
echo "To access the demo frontend:"
echo "  kubectl port-forward svc/$RELEASE_NAME-frontend -n $NAMESPACE 8080:8080"
echo "  Then open http://localhost:8080"
echo ""
echo "To access Jaeger UI (traces):"
echo "  kubectl port-forward svc/$RELEASE_NAME-jaeger-query -n $NAMESPACE 16686:16686"
echo "  Then open http://localhost:16686"
echo "=========================================================================="
