#!/usr/bin/env bash
set -euo pipefail

cluster_name="$1"
cluster_role="argocd-core-application"
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
config_repo_url="https://github.com/twplatformlabs/psk-platform-svc-dist-control-plane-config"

echo "cluster_name: $cluster_name"
echo "cluster_role: $cluster_role"
echo "argocd_namespace: $argocd_namespace"
echo "config_repo_url: $config_repo_url"

cat <<EOF > tpl/test-configuration.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-configuration
  namespace: $argocd_namespace
  labels:
    app.kubernetes.io/managed-by: psk-platform-svc-dist-control-plane-config
spec:
  project: psk-aws-control-plane-configuration

  source:
    repoURL: $config_repo_url
    targetRevision: HEAD
    path: test/${cluster_role}
    directory:
      recurse: true
      include: "**/application.yaml"

  destination:
    server: https://kubernetes.default.svc
    namespace: $argocd_namespace

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# kubectl apply -f "tpl/test-configuration.yaml"

# # wait for the application to be ready

# # Port-forward and hit the health endpoints
# kubectl port-forward -n podinfo svc/podinfo 9898:9898

# curl http://localhost:9898/healthz
# curl http://localhost:9898/readyz
# curl http://localhost:9898/version