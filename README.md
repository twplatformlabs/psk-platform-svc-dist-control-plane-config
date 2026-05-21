<div align="center">
	<p>
	<img alt="Thoughtworks Logo" src="https://raw.githubusercontent.com/twplatformlabs/static/master/psk_banner.png" width=800 />
	<h2>psk-platform-svc-dist-control-plane-config</h2>
	<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/github/license/twplatformlabs/psk-platform-svc-dist-control-plane-config"></a> <a href="https://aws.amazon.com"><img src="https://img.shields.io/badge/-deployed-blank.svg?style=social&logo=amazon"></a>
	</p>
</div>

Deploy argocd core to control plane and set to centralized 'role-based' configuration repo. The cluster is mapped to a role in an argo app-of-apps cofiguration repp which maintains all the cluster-level services and extensions.  

This configuration is based on a standard Application definition in order to support enforced syncWave order values.  

The configuration repo is [psk-aws-control-plane-configuration](https://github.com/twplatformlabs/psk-aws-control-plane-configuration)

WHen moving to a role-based automated configuration, the individual service and extension pipelines immediately benefit from a global_env_values variable that dynamicaly roles application upgrades to all clusters and roles. Without this, the individual svc and ext pipelines must each be modified when adding new roles.  

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