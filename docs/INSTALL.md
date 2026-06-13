# Install Jama Connect into an existing Kubernetes cluster

> This deploys the **converted, vendor-neutral** chart. The Jama application
> images/tags must first be reconciled from a license (see
> [CONVERSION.md](CONVERSION.md)). Until then, installs will reference placeholder
> `jama/*` images and pods will not pull successfully — that is expected.

## Prerequisites

- Kubernetes **≥ 1.25**, `kubectl`, `helm ≥ 3.10` (and `kustomize ≥ 5` for the GitOps path).
- A **default or named StorageClass** for block PVCs, and an **RWX-capable
  StorageClass** (NFS/CephFS/EFS/Azure Files) for the shared `tenantfs` volume.
- An **ingress controller** (NGINX) or **Contour** (for `ingress.type=httpproxy`).
- An **external database** reachable from the cluster: MySQL 8.0/8.4 or MS SQL
  Server 2022, with the three Jama databases pre-created and a user/password.
- A **Jama license** and access to the Jama image registry.
- Nodes with `vm.max_map_count >= 262144` (for Elasticsearch) — or allow the
  chart's privileged sysctl init container.

Run the preflight helper:

```bash
./scripts/preflight.sh jama
```

## 1. Create the namespace and operator secrets

```bash
kubectl create namespace jama

# License (entitlement — required)
kubectl -n jama create secret generic jama-license --from-file=license.yaml=./license.yaml

# Database credentials
kubectl -n jama create secret generic jama-db \
  --from-literal=username='jama' --from-literal=password='REDACTED'

# Image pull secret (Jama/Replicated registry)
kubectl -n jama create secret docker-registry jama-registry \
  --docker-server='registry.replicated.com' \
  --docker-username='REDACTED' --docker-password='REDACTED'

# Optional: SMTP, TLS, SAML/OIDC (see manifests/operator-secrets/README.md)
```

## 2. Choose your config

Edit the appropriate env values file (`values/dev.yaml`, `values/staging.yaml`,
`values/prod.yaml`). At minimum set:

```yaml
global:
  fqdn: "jama.example.com"
  storageClass: "your-block-sc"
  imageRegistry: "registry.replicated.com"   # or your mirror
  imageTag: "9.x.y"                            # from kots pull
  imagePullSecrets: [ { name: jama-registry } ]
database:
  type: mysql            # or sqlserver
  host: "db.example.com"
  existingSecret: "jama-db"
license:
  existingSecret: "jama-license"
sharedStorage:
  tenantfs:
    storageClass: "your-rwx-sc"
ingress:
  className: "nginx"
  tls: { enabled: true, secretName: "jama-tls" }
```

## Validate before applying

```bash
helm lint charts/jama-connect
helm template jama charts/jama-connect -n jama -f values/prod.yaml | kubeconform -strict -ignore-missing-schemas -summary
```

## 3a. Install with Helm

```bash
helm upgrade --install jama charts/jama-connect \
  --namespace jama --create-namespace \
  -f values/prod.yaml
```

## 3b. Or render with Kustomize (GitOps)

```bash
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone overlays/prod | kubectl apply -f -
```

**Argo CD**: enable Helm in Kustomize by setting
`kustomize.buildOptions: --enable-helm --load-restrictor LoadRestrictionsNone`
(in `argocd-cm`), then point an `Application` at `overlays/prod`.

**Flux**: either a `Kustomization` with the same build options, or a `HelmRelease`
referencing `charts/jama-connect` with `values/prod.yaml`.

## 4. Verify

```bash
kubectl -n jama get pods,sts,deploy,svc,pvc,ingress
helm test jama -n jama        # runs the bundled connection test
```

Browse to `https://<fqdn>` once `nginx`/`core` pods are ready and the
`tenant-manager` Job has completed.

## Troubleshooting

- **Pods `ImagePullBackOff`** → image registry/tag/pull-secret not reconciled yet
  (see [CONVERSION.md](CONVERSION.md)).
- **`tenantfs` PVC Pending** → no RWX StorageClass; set `sharedStorage.tenantfs.storageClass`.
- **Elasticsearch CrashLoop** → `vm.max_map_count` too low; ensure the sysctl init
  container is enabled or tune the nodes.
- **DB connection errors** → verify the three databases exist and the user has
  ≥300 max connections.
