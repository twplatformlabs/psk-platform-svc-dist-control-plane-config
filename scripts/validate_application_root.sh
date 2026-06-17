#!/usr/bin/env bash
set -euo pipefail

cluster_name="$1"
cluster_role=$(jq -er .cluster_role environments/$cluster_name.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
application_root="$cluster_name-configuration"

# Set namespace context so core mode works without -n on every command
kubectl config set-context --current --namespace="${argocd_namespace}"

# Login in core mode (spawns local API server transparently per-command)
argocd login --core

# Now use full argocd CLI as normal
argocd app wait "${application_root}" \
  --sync \
  --health \
  --operation \
  --timeout 300

# Wait for child apps (app-of-apps pattern)
argocd app list -o name | grep -v "^${application_root}$" | while read -r child; do
  argocd app wait "${child}" --sync --health --operation --core --timeout 300
done

echo "application resource reports synced and healthy"

trap 'echo "=== FAILURE STATE ==="; \
  argocd app get otel-daemonset || true; \
  kubectl -n <otel-namespace> get ds -o wide || true; \
  kubectl -n <otel-namespace> describe ds <otel-ds-name> || true; \
  kubectl get nodes -o wide || true; \
  kubectl -n <otel-namespace> get pods -l <otel-selector> -o wide || true' ERR