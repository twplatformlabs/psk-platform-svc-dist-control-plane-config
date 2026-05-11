#!/usr/bin/env bash
set -euo pipefail

cluster_name="$1"
cluster_role=$(jq -er .cluster_role environments/$cluster_name.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
config_repo_url=$(jq -er .config_repo_url environments/$cluster_name.json)

cat <<EOF > tpl/$cluster_name-configuration.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $cluster_name-configuration
  namespace: $argocd_namespace
  labels:
    app.kubernetes.io/managed-by: psk-platform-svc-dist-control-plane-config
spec:
  project: psk-aws-control-plane-configuration

  source:
    repoURL: $config_repo_url
    targetRevision: main
    path: roles/${cluster_role}
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
    retry:
      limit: 10
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 5m
EOF
kubectl apply -f "tpl/$cluster_name-configuration.yaml"

cat <<EOF > tpl/register-repo.yaml
apiVersion: v1
kind: Secret
metadata:
  name: psk-aws-control-plane-configuration-repo
  namespace: $argocd_namespace
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/twplatformlabs/psk-aws-control-plane-configuration
EOF
kubectl apply -f "tpl/register-repo.yaml"