# Image inventory

> **Status:** Jama application images are **not** in the bundle. Populate the
> Jama rows from `./scripts/reconcile-images.sh ./_kots-rendered` after running
> `scripts/kots-pull.sh` with a license. Registry/tags below are placeholders
> marked `# OPERATOR:`.

## Jama application images (TODO — from `kots pull`)

The chart maps one image per `components.<name>` plus the tenant-manager Job.
Default repositories are placeholders (`jama/<name>`); real values come from the
licensed render.

| Component | values path | Repository (placeholder) | Tag | Registry | Owner |
| --- | --- | --- | --- | --- | --- |
| core | `components.core.image` | `jama/core` | `# OPERATOR` | `global.imageRegistry` | Jama |
| core-ingress | `components.core-ingress.image` | `jama/core-ingress` | `# OPERATOR` | ″ | Jama |
| core-jobs | `components.core-jobs.image` | `jama/core-jobs` | `# OPERATOR` | ″ | Jama |
| core-reports | `components.core-reports.image` | `jama/core-reports` | `# OPERATOR` | ″ | Jama |
| activemq | `components.activemq.image` | `jama/activemq` | `# OPERATOR` | ″ | Jama/3rd-party |
| hazelcast | `components.hazelcast.image` | `jama/hazelcast` | `# OPERATOR` | ″ | Jama/3rd-party |
| elasticsearch | `components.elasticsearch.image` | `jama/elasticsearch` | `# OPERATOR` | ″ | 3rd-party (Elastic) |
| search | `components.search.image` | `jama/search` | `# OPERATOR` | ″ | Jama |
| diff | `components.diff.image` | `jama/diff` | `# OPERATOR` | ″ | Jama |
| saml | `components.saml.image` | `jama/saml` | `# OPERATOR` | ″ | Jama |
| oauth | `components.oauth.image` | `jama/oauth` | `# OPERATOR` | ″ | Jama |
| nginx | `components.nginx.image` | `jama/nginx` | `# OPERATOR` | ″ | 3rd-party (NGINX) |
| tenant-manager | `tenantManager.image` | `jama/tenant-manager` | `# OPERATOR` | ″ | Jama |

The sysctl init container uses `busybox:1.36` (configurable via
`elasticsearch.sysctlImage`); chart tests use `curlimages/curl`.

## Infrastructure images in the bundle (NOT deployed by this chart)

Observed in the kURL bundle, listed for completeness; these are **removed** in the
conversion (provided by your cluster) — see [CONVERSION.md](CONVERSION.md).

| Image group | Version | Role | Disposition |
| --- | --- | --- | --- |
| kotsadm / rqlite / dex / kurl-proxy | kotsadm 1.129.4 | KOTS admin console | Removed |
| openebs (provisioner/localpv) | 4.4.0 | Local-PV storage | Replaced by StorageClass |
| minio | 2025-10-15 | object storage (snapshots) | Removed |
| registry | 3.0.0 | in-cluster registry | Replaced by your registry |
| prometheus / grafana stack | 0.88.1-81.5.0 | monitoring | Removed (optional ServiceMonitor) |
| velero | 1.16.2 | backup/restore | Removed |
| cert-manager | 1.19.3 | TLS | Removed (use cluster cert-manager) |
| flannel / containerd / metrics-server / ekco | — | cluster bootstrap | Removed |
