#!/usr/bin/env bash
set -euo pipefail

cluster_name="$1"
cluster_role=$(jq -er .cluster_role environments/$cluster_name.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
application_root="$cluster_name-configuration"

# Start local ArgoCD API server in background
argocd admin local-server \
  --namespace "${argocd_namespace}" \
  --port 8080 &
LOCAL_SERVER_PID=$!

# Give it a moment to establish connection
sleep 5

export ARGOCD_SERVER=localhost:8080

# Cleanup on exit
trap "kill ${LOCAL_SERVER_PID} 2>/dev/null || true" EXIT

# Now use full argocd CLI as normal
argocd app wait "${application_root}" \
  --sync \
  --health \
  --operation \
  --timeout 300

# Wait for child apps (app-of-apps pattern)
argocd app list -o name | grep -v "^${application_root}$" | while read -r child; do
  argocd app wait "${child}" --sync --health --timeout 300
done

echo "application resource reports synced and healthy"