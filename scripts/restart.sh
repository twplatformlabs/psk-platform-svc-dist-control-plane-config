kubectl rollout restart deployment argocd-applicationset-controller -n psk-system
kubectl rollout restart deployment argocd-redis -n psk-system
kubectl rollout restart deployment argocd-repo-server -n psk-system
kubectl rollout restart statefulset argocd-application-controller -n psk-system