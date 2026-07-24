#!/bin/bash

# Configuration
NAMESPACE="opentelemetry"

# BindPlane OP Environment details
BINDPLANE_URL="<YOUR_BINDPLANE_OP_WEBSOCKET_URL>" # e.g. wss://bindplane.example.com:4317
BINDPLANE_SECRET_KEY="<YOUR_BINDPLANE_SECRET_KEY>"

echo "==> 1. Installing cert-manager (prerequisite for OpenTelemetry Operator)..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

echo "==> Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s

echo "==> 2. Adding Helm repositories..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add observiq https://observiq.github.io/bindplane-op-helm
helm repo update

echo "==> Creating namespace $NAMESPACE if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Installing OpenTelemetry Operator..."
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace $NAMESPACE \
  --set "manager.collectorImage.repository=otel/opentelemetry-collector-k8s"

echo "==> Waiting for OpenTelemetry Operator to be ready..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=opentelemetry-operator -n $NAMESPACE --timeout=300s

echo "==> 4. Installing BindPlane Agent..."
helm upgrade --install bindplane-agent observiq/bindplane-agent \
  --namespace $NAMESPACE \
  --set secretKey="${BINDPLANE_SECRET_KEY}" \
  --set remoteURL="${BINDPLANE_URL}"

echo "==> 5. Generating Auto-Instrumentation manifest..."
cat <<EOF > otel-operator-config.yaml
---
# This defines the auto-instrumentation rules for your apps
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: my-instrumentation
  namespace: $NAMESPACE
spec:
  exporter:
    endpoint: http://bindplane-agent.$NAMESPACE.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
    - b3
  sampler:
    type: parentbased_traceidratio
    argument: "1"
EOF

echo "==> 6. Applying Instrumentation resources..."
kubectl apply -f otel-operator-config.yaml

echo "=========================================================================="
echo "Deployment Complete!"
echo ""
echo "To auto-instrument your application, add this annotation to your app's pod/deployment spec:"
echo "  instrumentation.opentelemetry.io/inject-java: \"$NAMESPACE/my-instrumentation\""
echo "  (Replace 'inject-java' with 'inject-nodejs', 'inject-python', or 'inject-dotnet' as needed)"
echo "=========================================================================="
