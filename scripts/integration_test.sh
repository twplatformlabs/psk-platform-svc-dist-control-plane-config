#!/usr/bin/env bash
set -euo pipefail

cluster_name="$1"
cluster_role="argocd-core-application"
argocd_namespace=$(jq -er .argocd_namespace environments/$cluster_name.json)
config_repo_url="https://github.com/twplatformlabs/psk-platform-svc-dist-control-plane-config"
RED='\033[0;31m'
NC='\033[0m' # No Colour
fail() { echo -e "${RED}  ✗ FAIL${NC} $*"; }

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

kubectl apply -f "tpl/test-configuration.yaml"

# wait for the application to be ready
kubectl rollout status deployment/podinfo -n "$argocd_namespace" --timeout=120s || true


#===============
# confirm podinfo test-fixture health
kubectl port-forward "svc/podinfo" "9898:9898" -n "$argocd_namespace" &>/dev/null &
PF_PID=$!
echo "Waiting for port-forward to be ready..."
for i in $(seq 1 30); do
  if bash -c "echo > /dev/tcp/localhost/9898" 2>/dev/null; then
    echo "Port-forward ready after ${i}s"
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "Timed out waiting for port-forward"
    exit 1
  fi
  sleep 1
done

echo "direct check"
curl  "http://localhost:9898/readyz"

set +e
http_code="200"
http_code=$(curl -s -o podinfo_response -w "${http_code}" --max-time 5 "http://localhost:9898/readyz" 2>/dev/null)
response=$(cat podinfo_response 2>/dev/null || echo "")
echo "reponse: ${response}"

if [[ "${http_code}" != "200" ]]; then
  fail "expected HTTP 200, got HTTP ${http_code}"
  exit 1
fi

if ! echo "${response}" | grep -q "OK"; then
  fail "HTTP 200 returned but body did not contain 'OK'"
  fail "Body: ${response}"
  exit 1
fi

echo "app-of-appd integration test succeeded"

echo "Cleaning up..."
if [[ -n "${PF_PID}" ]] && kill -0 "${PF_PID}" 2>/dev/null; then
  kill "${PF_PID}" 2>/dev/null && echo "Port-forward (PID ${PF_PID}) stopped."
fi

# Also kill any stray port-forwards targeting the same port,
# in case a previous run didn't clean up
pkill -f "port-forward.*9898:9898" 2>/dev/null || true

echo "removing test-configuration app-of-app defintion"
kubectl delete -f "tpl/test-configuration.yaml"
echo "remove podinfo app definition"
kubectl delete application podinfo -n psk-system
echo "done cleanup"
