<div align="center">
	<p>
	<img alt="Thoughtworks Logo" src="https://raw.githubusercontent.com/twplatformlabs/static/master/psk_banner.png" width=800 />
	<h2>psk-platform-svc-dist-control-plane-config</h2>
	<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/github/license/twplatformlabs/psk-platform-svc-dist-control-plane-config"></a> <a href="https://aws.amazon.com"><img src="https://img.shields.io/badge/-deployed-blank.svg?style=social&logo=amazon"></a>
	</p>
</div>

Deploy argocd core to control plane and link to centralized 'role-based' configuration repo. The cluster is mapped to a role in an argo app-of-apps cofiguration repp which maintains all the cluster-level services and extensions.  

This configuration is based on a standard Application definition (app-of-apps) in order to support enforced syncWave order values.  

```mermaid
---
title: Role-based configuration management install
---
flowchart LR

    ARGO --> EKS --> | targeting cluster Role | SBX & PROD
    subgraph psk-aws-control-plane-configuration repo
        SBX["/sandbox"]
        PROD["/production"]
    end

    EKS@{ shape: procs, label: "EKS Cluster"}
    ARGO@{ shape: brace-r, label: "ArgoCD Core" }
```
The configuration repo is [psk-aws-control-plane-configuration](https://github.com/twplatformlabs/psk-aws-control-plane-configuration) and defines all the services and extensions for the cluster with the specific deployment configuration values.  
```bash
roles/
├── sandbox/
│   ├── external-secrets-operator/
│   ├── crossplane/
│   ├── metrics-server/
│   ├── kube-state-metrics/
│   ├── otel-collector/
│   ├── cert-manager/
│   ├── external-dns/
│   └── istio/
│
├── production
│   ├── external-secrets-operator/
│   ├── crossplane/
│   ├── metrics-server/
│   ├── kube-state-metrics/
│   ...
```
```mermaid
---
title: Each individual svc or ext pipeline
---
flowchart LR

    PUSH --> DEP --> SBX
    TAG --> REL --> PROD

    subgraph app-of-apps repo
        SBX["/sandbox"]
        PROD["/production"]
    end

    DEP@{ shape: brace-r, label: "$ git push" }
    REL@{ shape: brace-r, label: "$ git tag x.x.x" }

    PUSH@{ shape: das, label: "svc or ext pipeline..." }
    TAG@{ shape: das, label: "svc or ext pipeline..." }
```
Ihe individual service or extension pipelines define the change release for the application by modifying the respective information in the app-of-apps repo.

Currently the application pipelines also manage integration testing and therefore must be aware of each cluster in order to perform testing. These pipeline would also benefit from creating a central list of clusters by-role where the application pipeline could dynamically generate a parallelized testing pipeline.

### maintainers

**Upgrades**  

The install script uses the environment defined argocd version value to map to the core menifest file in particular folder. For example, argocd v3.3.7 manifests are in the `argocd-core-manifest-3.3.7` folder.  

To upgrade argocd core, follow the upgrade instructions [here](doc/upgrade-manifeset.md).  

The install script defines an org sa access token. The role configuration registers the configuration repo.  

**UI access**

```bash
argocd login --core     # uses current kubeconfig context
argocd admin dashboard  # then launches a dashboard locally

starting dashboard
Argo CD UI is available at http://localhost:8080
```
