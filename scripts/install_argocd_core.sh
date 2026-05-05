#!/usr/bin/env bash
set -euo pipefail

cluster_name="$1"

argocd_version=$(jq -er .argocd_version environments/$cluster_name.json)
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
config_repo_url=$(jq -er .config_repo_url environments/$cluster_name.json)

echo "cluster_name: $cluster_name"
echo "argocd_version: $argocd_version"
echo "argocd_namespace: $argocd_namespace"
echo "config_repo_url: $config_repo_url"

# perform trivy scan of chart with install configuration
trivy config "argocd-core-manifest-${argocd_version}"

# starting at 3.3.7 to goto 3.3.9
# manifest deploy is documented approach. The offical helm chart will still deploy the server even though it is not needed.

# deploy clusterrolebinding as template, namespace definition is required.
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
kubectl apply -f tpl/cluster-role-binding.yaml

cat <<EOF > tpl/pdb.yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-repo-server
  namespace: $argocd_namespace
spec:
  maxUnavailable: 1        # allows eviction of the single pod
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server

---
# application-controller StatefulSet
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-applicationset-controller
  namespace: $argocd_namespace
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-applicationset-controller

---
# application-controller StatefulSet
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-application-controller
  namespace: $argocd_namespace
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller

---
# redis
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-redis
  namespace: $argocd_namespace
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-redis
EOF
kubectl apply -f tpl/pdb.yaml

kubectl apply -n psk-system --server-side --force-conflicts --recursive -f "argocd-core-manifest-${argocd_version}/"

# report on rollout status
kubectl rollout status deployment/argocd-applicationset-controller \
  -n "$argocd_namespace" --timeout=120s || true
kubectl rollout status deployment/argocd-repo-server \
  -n "$argocd_namespace" --timeout=120s || true
kubectl rollout status deployment/argocd-redis \
  -n "$argocd_namespace" --timeout=120s || true
kubectl rollout status statefulset/argocd-application-controller \
  -n "$argocd_namespace" --timeout=120s || true


cat <<EOF > tpl/cluster-configuration-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: psk-aws-control-plane-configuration
  namespace: $argocd_namespace
spec:
  description: Only allows twplatformlabs/psk-aws-control-plane-configuration as source repo.

  sourceRepos:
    - https://github.com/twplatformlabs/*

  destinations:
    - namespace: "*"
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: "*"
      kind: "*"

  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
EOF
kubectl apply -f tpl/cluster-configuration-project.yaml


# if there's reason to switch back to argocd as the deplyment ns, then need to create it
# cat <<EOF > tpl/namespace.yaml
# ---
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: argocd
#   labels:
#     app.kubernetes.io/managed-by: psk-platform-svc-dist-control-plane-config
# EOF
# kubectl apply -f tpl/namespace.yaml