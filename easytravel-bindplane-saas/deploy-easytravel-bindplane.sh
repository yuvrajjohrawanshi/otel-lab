#!/bin/bash
set -e

# ==============================================================================
# deploy-easytravel-bindplane.sh
# Deploys Auto-Instrumented Dynatrace easyTravel configured for BindPlane SaaS
# ==============================================================================

NAMESPACE="otel-demo"
MANIFESTS_DIR="easytravel-manifests"

echo "=========================================================================="
echo "==> 1. Ensuring target namespace ($NAMESPACE) exists..."
echo "=========================================================================="
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "=========================================================================="
echo "==> 2. Removing standalone otel-collector (if any) to save memory..."
echo "=========================================================================="
kubectl delete deployment otel-collector -n $NAMESPACE --ignore-not-found=true
kubectl delete svc otel-collector -n $NAMESPACE --ignore-not-found=true
kubectl delete configmap otel-collector-config -n $NAMESPACE --ignore-not-found=true

echo "=========================================================================="
echo "==> 3. Deploying Auto-Instrumented easyTravel Application..."
echo "=========================================================================="
kubectl apply -f "$MANIFESTS_DIR" -n $NAMESPACE

echo "=========================================================================="
echo "  EASYTRAVEL DEPLOYED FOR BINDPLANE SAAS!  "
echo "=========================================================================="
echo ""
echo "NEXT STEPS — DEPLOY THE BINDPLANE AGENT FROM SAAS UI:"
echo "1. Log in to your BindPlane SaaS tenant: https://app.observiq.com"
echo "2. Go to 'Agents' -> Click 'Install Agent' -> Select 'Kubernetes'."
echo "3. Copy the generated kubectl apply/helm install command and run it in your terminal."
echo "4. In the UI, create a Configuration with an OTLP Source (ports 4317/4318) and a"
echo "   New Relic Destination, then attach it to your new agent."
echo ""
echo "To watch easyTravel pod status:"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
echo "To watch BindPlane Agent pod status:"
echo "  kubectl get pods -n bindplane-agent -w"
echo ""
echo "To access easyTravel Frontend on KillerCoda (Traffic -> Port 80):"
echo "  kubectl port-forward svc/angular-nginx-service -n $NAMESPACE 80:80 --address 0.0.0.0"
echo ""
echo "To check BindPlane Agent logs via kubectl:"
echo "  kubectl logs -l app.kubernetes.io/name=bindplane-node-agent -n bindplane-agent -f"
echo "  (Or simply click the 'Logs' tab on https://app.observiq.com)"
echo "=========================================================================="
