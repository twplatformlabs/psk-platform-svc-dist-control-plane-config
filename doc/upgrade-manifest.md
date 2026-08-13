## Upgrading the ArgoCD Core manifest deployment

The argocd-core deployment, per the current documentation, recommends using the single-file manifest for deployment. Core deployment is not yet included among the options supported by the Helm charts. However, it also means that we need to pull the manifest and make modifications to support the architecture. In particular, targeting the management-node-group for deployment and including resource assignments and liveness/readiness probes.  

>NOTE: need to detail exactly how to compile this list of resources from the manifests  

Generally the upgrade patterns is like this:

1. Review the upgrade and release notes
2. Pull a copy of the new manifest
3. Assess whether the new version deletes any prior CRDs, add the idempotent deletion to the install script (can remove afterwards).
4. Create a new version folder named as `argocd-core-manifest-<version>`
5. The manifest is divided up by resource type. They general are in the order below. Create resource files for the new version resources in the new version manifest folder:
  a. crds.yaml
  b. serviceaccounts.yaml
  c. services.yaml
  d. roles.yaml
  e. secrets.yaml
  f. configmaps.yaml
  g. deployment-applicationset-controller.yaml
  h. depoyment-redis.yaml
  i. deployment-repo-server.yaml
  j. statefulset-argocd-core.yaml
  k. networkpolicy.yaml
6. REmove the ClusterRoleBinding from the role.yaml resource, being sure to compare the configuration to what is used in the install script. This role binding requires the namespace specification so it is templated.  
7. The following additions


For the three deployments and the statefulset, make the following modifications:  

Use this definition for the spec.template.spec.securityContext definition for each:
```yaml
  containerSecurityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
    seccompProfile:
      type: RuntimeDefault
```

Add the node selector and tolerations to spce.template.spec for each:  
```yaml
nodeSelector:
  nodegroup: management-arm-rkt-mng
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "management"
    effect: "NoSchedule"
```

for just the applicationset-controller:  
```yaml
ports:
  - containerPort: 7000
    name: webhook
  - containerPort: 8080
    name: metrics
  - containerPort: 8081
    name: probe
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
readinessProbe:
  httpGet:
    path: /healthz
    port: probe
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /healthz
    port: probe
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3

```

For just the Redis deployment:  
```yaml
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  readinessProbe:
    tcpSocket:
      port: 6379
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 6
  livenessProbe:
    tcpSocket:
      port: 6379
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 6
```

For just the repo-server deployment:  
```yaml
  resources:
    limits:
      cpu: 50m
      memory: 128Mi
    requests:
      cpu: 10m
      memory: 64Mi
  ports:
  - name: repo-server
    containerPort: 8081
    protocol: TCP
  - name: metrics
    containerPort: 8084
    protocol: TCP
  livenessProbe:
    httpGet:
      path: /healthz?full=true
      port: metrics
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /healthz
      port: metrics
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 3
    successThreshold: 1
    failureThreshold: 3
```

For just the argocd-core statefulset:  
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```