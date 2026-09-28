#!/usr/bin/env bash
# Installs kube-prometheus-stack (Prometheus, Alertmanager, Grafana) scoped down
# for a local kind cluster. Values are kept minimal on purpose: this repo cares
# about the Prometheus query surface Argo Rollouts' AnalysisTemplates hit, not
# about a full observability stack.
set -euo pipefail

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.enabled=true \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=6h \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set alertmanager.enabled=false \
  --wait --timeout 5m

echo "Prometheus: kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
echo "Grafana:    kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80  (admin/admin)"
