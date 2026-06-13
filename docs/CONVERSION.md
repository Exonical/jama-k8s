# Conversion approach & KOTS/kURL replacement map

## Why a hybrid Helm + Kustomize design

KOTS applications are **heavily templated** (`repl{{ ConfigOption … }}`), so a
Helm chart is the natural base (Helm > Kustomize when there is significant
templating). For GitOps we layer **Kustomize overlays** on top via the
`helmCharts:` integration, so Argo CD / Flux can render per-environment output
from a single chart.

```
charts/jama-connect/   # the Helm chart (base, fully templated)
values/{dev,staging,prod}.yaml   # per-env Helm values (single source of truth)
overlays/{dev,staging,prod}/     # Kustomize wrappers -> `kustomize build --enable-helm`
manifests/             # raw namespace + operator-secret TEMPLATES (no Helm)
scripts/               # license-respecting extraction + preflight
```

## KOTS/kURL component → replacement map

| Bundle component | KOTS/kURL role | Disposition in this repo |
| --- | --- | --- |
| `install.sh`/`join.sh`/`upgrade.sh`/`tasks.sh` | kURL cluster lifecycle | **Removed** — existing cluster |
| `packages/kubernetes`, `containerd` | host k8s/runtime | **Removed** — cluster provides |
| `flannel` | CNI | **Removed** — cluster CNI |
| `ekco` | kURL operator | **Removed** |
| `metrics-server` | metrics | **Removed** — cluster provides |
| `openebs` LocalPV (`local`) | default storage | **Replaced** → `global.storageClass` value |
| in-cluster `registry` | airgap image host | **Replaced** → your registry + `global.imagePullSecrets` |
| `kotsadm`/`rqlite`/`dex`/`kurl-proxy` | admin console + config UI | **Removed** → Helm values + GitOps |
| KOTS `Config` screens / `repl{{…}}` | config templating | **Replaced** → `values.yaml` (Helm) |
| KOTS Preflights / support-bundle | host/cluster checks | **Replaced** → `scripts/preflight.sh` + docs |
| `minio` | object storage for snapshots | **Removed** — use your backup target if needed |
| `velero` | backup/restore | **Removed** — use your cluster's backup strategy |
| `prometheus` stack | monitoring | **Removed** → optional `ServiceMonitor` (`monitoring.serviceMonitor`) |
| `cert-manager` | TLS | **Removed** → `ingress.tls` + issuer annotations (use cluster cert-manager) |
| KOTS license | entitlement | **Preserved** — provided as a Secret (`license.existingSecret`) |
| Jama app workloads/images | the application | **Templated** in the chart; images/tags are `# OPERATOR:` placeholders until `kots pull` |

## Reconciliation checklist (run when a license/.airgap is available)

1. **Render the real manifests** (preserves licensing):
   ```bash
   ./scripts/kots-pull.sh -l license.yaml -n jama -p 'admin-console-pw' -o ./_kots-rendered
   # airgap: add -a jama-k8s.airgap
   ```
2. **Extract the image inventory** and fill [IMAGE-INVENTORY.md](IMAGE-INVENTORY.md):
   ```bash
   ./scripts/reconcile-images.sh ./_kots-rendered
   ```
3. **Reconcile workloads** against `charts/jama-connect/values.yaml`:
   - Confirm component names/kinds (StatefulSet vs Deployment) and replica counts.
   - Confirm container **ports**, **env vars**, **probes**, **resources**.
   - Confirm **volume mount paths** and `volumeClaimTemplate` names (PVC naming
     `volume-<component>-0` must match Jama's expectations).
   - Confirm the **shared `tenantfs`** RWX mount path and size.
   - Confirm DB env var names and the three logical database names.
4. **Set image references**: `global.imageRegistry`, `global.imageTag`, and any
   per-component `components.<name>.image.*` overrides.
5. **Re-validate**: `helm lint`, `helm template`, `kustomize build --enable-helm`,
   and `kubeconform` (see [INSTALL.md](INSTALL.md#validate-before-applying)).
6. **Commit** only the reconciled chart/values — never `_kots-rendered/` (it may
   contain license-derived secrets; it is in `.gitignore`).

## What cannot be cleanly extracted (depends on KOTS runtime)

- **KOTS Config UI logic** (conditional fields, computed defaults, validation):
  re-expressed as `values.yaml` + chart templating; complex conditionals may need
  manual translation.
- **`repl{{ … }}` runtime functions** (e.g. `{{repl ... | nindent}}`, TLS cert
  generation, random secret generation): replaced by Helm functions or
  operator-provided Secrets.
- **kotsadm-managed upgrades/backups/snapshots**: replaced by GitOps + your
  cluster backup tooling (see [UPGRADE.md](UPGRADE.md)).
- **Embedded preflight/support-bundle collectors**: replaced by `scripts/preflight.sh`
  and documented prerequisites.
