#!/bin/bash

# Configuration
NAMESPACE="opentelemetry"
DEMO_RELEASE_NAME="dynatrace-otel-demo"

# Dynatrace Environment details
DYNATRACE_URL="<YOUR_DYNATRACE_ENVIRONMENT_URL>/api/v2/otlp"
DYNATRACE_TOKEN="<YOUR_DYNATRACE_API_TOKEN>" # Token needs metrics.ingest, traces.ingest, logs.ingest scopes

echo "==> Creating namespace $NAMESPACE if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating Dynatrace credentials secret for the demo..."
kubectl create secret generic dt-credentials \
  --namespace $NAMESPACE \
  --from-literal=DT_ENDPOINT="$DYNATRACE_URL" \
  --from-literal=DT_API_TOKEN="$DYNATRACE_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying Dynatrace OpenTelemetry Demo via Helm..."
# We use the local chart from the repository you just cloned
helm upgrade --install $DEMO_RELEASE_NAME "$(dirname "$0")/opentelemetry-demo/charts/astroshop" \
  --namespace $NAMESPACE \
  --set "components.dt-credentials.enabled=false"

echo "=========================================================================="
echo "Dynatrace OpenTelemetry Demo Deployment Initiated!"
echo ""
echo "Run 'kubectl get pods -n $NAMESPACE' to monitor the startup."
echo "Note: The demo creates many microservices and its own gateway collector."
echo "      It will automatically authenticate and send data to Dynatrace using"
echo "      the secret we just created."
echo "=========================================================================="
