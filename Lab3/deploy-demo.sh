#!/bin/bash

# Configuration
NAMESPACE="astroshop"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_DIR="$SCRIPT_DIR/opentelemetry-demo"

# Dynatrace Environment details
DYNATRACE_URL="<YOUR_DYNATRACE_ENVIRONMENT_URL>/api/v2/otlp"
DYNATRACE_TOKEN="<YOUR_DYNATRACE_API_TOKEN>" # Token needs metrics.ingest, traces.ingest, logs.ingest scopes

echo "==> Updating Dynatrace credentials in values.yaml..."
cat > "$DEMO_DIR/kustomize/base/values.yaml" <<EOF
components:
  ingress:
    enabled: false
  dt-credentials:
    enabled: true
    tenantEndpoint: ${DYNATRACE_URL}
    tenantToken: ${DYNATRACE_TOKEN}
EOF

echo "==> Deploying Dynatrace OpenTelemetry Demo via Kustomize + Helm..."
kustomize build \
    --enable-helm \
    --load-restrictor LoadRestrictionsNone \
    "$DEMO_DIR/kustomize/base" | kubectl apply -f -

echo "=========================================================================="
echo "Dynatrace OpenTelemetry Demo Deployment Initiated!"
echo ""
echo "Run 'kubectl get pods -n $NAMESPACE' to monitor the startup."
echo "Note: The demo creates many microservices and its own gateway collector."
echo "      It will automatically authenticate and send data to Dynatrace using"
echo "      the credentials configured in values.yaml."
echo "=========================================================================="
