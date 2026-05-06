#!/usr/bin/env bash
set -euo pipefail

# NOTE: not used in the pipeline. This is only for sandbox development and experimentation
cluster_name="$1"
cluster_role="$2"

argocd_version=$(jq -er .argocd_version environments/$cluster_name.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
config_repo_url=$(jq -er .config_repo_url environments/$cluster_name.json)

echo "cluster_name: $cluster_name"
echo "cluster_role: $cluster_role"
echo "argocd_version: $argocd_version"
echo "argocd_namespace: $argocd_namespace"
echo "config_repo_url: $config_repo_url"

cat <<EOF > tpl/cluster-role-binding.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: application-controller
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-application-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-application-controller
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: $argocd_namespace
EOF
kubectl delete -f tpl/cluster-role-binding.yaml
kubectl delete -n psk-system --recursive -f "argocd-core-manifest-${argocd_version}/"
kubectl delete secret argocd-redis -n $argocd_namespace