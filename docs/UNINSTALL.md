# Uninstall Jama Connect

## Helm

```bash
helm uninstall jama -n jama
```

Helm removes all chart-managed objects. **PVCs created by StatefulSet
`volumeClaimTemplates` are intentionally retained by Kubernetes** to protect data.

## Kustomize / GitOps

```bash
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone overlays/prod | kubectl delete -f -
```

For Argo CD/Flux, delete the `Application`/`Kustomization`/`HelmRelease` (disable
auto-prune protections first if enabled).

## Remove persistent data (DESTRUCTIVE)

Only after confirming backups. This permanently deletes Jama data volumes:

```bash
# List first
kubectl -n jama get pvc

# Delete the per-component volumes and the shared tenantfs claim
kubectl -n jama delete pvc -l app.kubernetes.io/instance=jama
# (or delete individually: volume-core-0, volume-elasticsearch-0, tenantfs, …)
```

## Operator-provided secrets & namespace

```bash
kubectl -n jama delete secret jama-license jama-db jama-smtp jama-registry jama-tls 2>/dev/null || true
kubectl delete namespace jama
```

## External resources NOT removed

- The **external database** and its three Jama databases (managed outside the cluster).
- Any **DNS records**, **TLS certificates** issued externally, or **backups**.
- Cluster-wide capabilities you did not install for Jama (ingress controller,
  cert-manager, monitoring).
