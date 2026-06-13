# Upgrade strategy (without KOTS)

KOTS/kotsadm previously managed version checks, config, and rollout. Without it,
upgrades are a normal **GitOps-driven Helm release bump**, gated by the license
re-render so entitlement is preserved.

## Flow

1. **Re-render the new Jama release** with your license (preserves entitlement):
   ```bash
   ./scripts/kots-pull.sh -l license.yaml -n jama -p 'admin-console-pw' -o ./_kots-rendered
   ```
2. **Diff** the rendered manifests against the chart to find changed images,
   env, ports, probes, or new/removed components:
   ```bash
   ./scripts/reconcile-images.sh ./_kots-rendered
   git diff -- charts/jama-connect/values.yaml
   ```
3. **Bump** `appVersion` in `charts/jama-connect/Chart.yaml` and update
   `global.imageTag` (and any per-component overrides) in the env values files.
4. **Validate**: `helm lint`, `helm template … | kubeconform`, `kustomize build`.
5. **Roll out**:
   ```bash
   helm upgrade jama charts/jama-connect -n jama -f values/prod.yaml
   ```
   or merge to the GitOps branch and let Argo CD/Flux sync.

## Database schema migrations

Jama applies schema migrations on startup of the `core` tier. **Back up the
external database before upgrading.** Roll out a single `core` replica first if
your release notes call for a controlled migration, then scale back up.

## StatefulSet considerations

- StatefulSets use `RollingUpdate`; pods update one ordinal at a time.
- PVCs are retained across upgrades (data preserved).
- For Elasticsearch major-version jumps, follow Jama's release notes — a reindex
  or snapshot/restore may be required.

## Rollback

```bash
helm rollback jama <REVISION> -n jama     # app/manifests only
```

A Helm rollback does **not** revert database schema migrations. Restore the DB
from backup if a release performed irreversible migrations.

## Recommended cadence

- Pin `global.imageTag` to an explicit Jama release (never `latest`).
- Stage every upgrade in `dev`/`staging` (smaller `values/*.yaml`) before `prod`.
- Keep `Chart.yaml` `version` (chart) and `appVersion` (Jama) bumped together.
