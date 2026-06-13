# Bundle analysis — Jama Connect KOTS/kURL installer

Source bundle: `https://k8s.kurl.sh/bundle/jama-k8s-standardkots.tar.gz`
(~5.4 GB, kURL installer version `v2026.05.18-0`).

This document classifies the bundle and explains what was removed/replaced to
make Jama Connect deployable into an **existing** Kubernetes cluster without the
KOTS/kURL installer flow.

> **Provenance of facts.** Items under "from the bundle" are observed directly in
> the tarball. Items under "from Jama public docs" come from Jama's published
> self-hosted documentation and are explicitly assumptions until reconciled
> against license-rendered manifests (see [CONVERSION.md](CONVERSION.md)).

## 1. Top-level layout (from the bundle)

```
jama-k8s-standardkots/
├── install.sh / join.sh / upgrade.sh / tasks.sh   # kURL cluster scripts
└── kurl/
    ├── addons/
    │   ├── cert-manager/1.19.3/
    │   ├── containerd/{1.6.33,1.7.29}/
    │   ├── ekco/0.28.14/                # kURL cluster operator
    │   ├── flannel/0.28.4/              # CNI
    │   ├── kotsadm/1.129.4/             # KOTS admin console (+ rqlite, dex, kurl-proxy)
    │   │   └── application.yaml         # KOTS Application metadata (name: jama-k8s)
    │   ├── metrics-server/0.8.1/
    │   ├── minio/2025-10-15T17-29-55Z/  # object storage (KOTS/velero snapshots)
    │   ├── openebs/4.4.0/               # Local-PV provisioner (StorageClass "local")
    │   ├── prometheus/0.88.1-81.5.0/    # kube-prometheus stack
    │   ├── registry/3.0.0/              # in-cluster registry (airgap images)
    │   └── velero/1.16.2/               # backup/restore
    ├── packages/{kubernetes/1.34.7,host}/
    ├── bin/ helm/ krew/ kurlkinds/ kustomize/kubeadm/ manifests/ shared/
```

Embedded kURL `Installer` spec (from `install.sh`):

```yaml
apiVersion: cluster.kurl.sh/v1beta1
kind: Installer
metadata: { name: jama-k8s-standardkots }
spec:
  kubernetes: { version: 1.34.7 }
  flannel:    { version: 0.28.4 }
  openebs:    { version: 4.4.0, isLocalPVEnabled: true, localPVStorageClassName: local }
  minio:      { version: 2025-10-15T17-29-55Z }
  registry:   { version: 3.0.0 }
  prometheus: { version: 0.88.1-81.5.0 }
  kotsadm:    { applicationSlug: jama-k8s/standardkots, version: 1.129.4 }
  velero:     { version: 1.16.2 }
  ekco:       { version: 0.28.14 }
```

Host preflights embedded in the installer: **≥8 CPU** (16 rec), **≥32 GB RAM**
(64 rec), **≥200 GB** root disk, and a check that **MySQL/MSSQL host packages are
NOT pre-installed** (the external database runs on a separate server).

## 2. Classification

### kURL-specific — removed (your cluster already provides these)
`install.sh`/`join.sh`/`upgrade.sh`/`tasks.sh`, `kurl/packages/*` (kubeadm,
kubelet, containerd host packages), and bootstrap addons `containerd`, `flannel`,
`ekco`, `metrics-server`, plus `kurl/bin`, `kurl/shared`, `kurl/kustomize/kubeadm`,
`kurlkinds`.

### KOTS-specific — removed (replaced by Helm + GitOps)
`kurl/addons/kotsadm/*` — the admin console (kotsadm, rqlite, dex, kurl-proxy),
its templated secrets and images; `krew` preflight/support-bundle plugins; and
`minio` + `velero` as configured here (they primarily serve KOTS snapshots).

### Plain Kubernetes — replaced by cluster services / values
`cert-manager` (TLS), `prometheus` (monitoring), `openebs` LocalPV (storage).
Each becomes an operator-provided cluster capability exposed via chart values.

### Jama-specific (from the bundle)
Only `kurl/addons/kotsadm/1.129.4/application.yaml` — the KOTS `Application`
metadata for **jama-k8s** ("Jama Connect"). **This is the only Jama-specific
artifact in the entire 5.4 GB bundle.**

## 3. Key finding — the Jama application is NOT in the tarball

The bundle is the **cluster installer only**. The deployable Jama workloads, their
images (`jamasoftware/*` or a Replicated registry path), KOTS Config templating,
ConfigMaps, PVCs, Services, and Ingress are **downloaded at install time by
kotsadm from `https://replicated.app`** using the customer's **Jama license**
(app slug `jama-k8s/standardkots`), or shipped as a separate `.airgap` bundle.

Therefore the real manifests/inventories **cannot be extracted from this tarball
alone**. They are obtained license-respectingly via either:

1. `kots pull jama-k8s/standardkots --license-file license.yaml` (renders the full
   app locally **without** installing KOTS), or
2. the Jama `.airgap` application bundle from the Jama/Replicated download portal.

`scripts/kots-pull.sh` wraps option (1)/(2). The license remains the entitlement
mechanism and is never removed.

## 4. Application topology (from Jama public self-hosted docs — assumptions)

The chart encodes the following topology, recovered from Jama's published
self-hosted documentation. **Treat names/ports as assumptions** until reconciled
against `kots pull` output.

- **StatefulSets:** `core`, `core-ingress`, `core-jobs`, `core-reports`,
  `activemq`, `hazelcast`, `elasticsearch` (3 replicas).
- **Deployments:** `saml`, `oauth`, `diff`, `search`, `nginx` (internal reverse proxy).
- **Job:** `tenant-manager` (tenant provisioning).
- **External database:** MySQL 8.0/8.4 **or** MS SQL Server 2022 on a separate
  server; **three** logical databases; ≥300 concurrent connections. NOT supported:
  Azure DB, MariaDB, AWS EKS (per Jama docs).
- **Ingress:** Contour (HTTPProxy) in the appliance; this chart supports both a
  standard `Ingress` and a Contour `HTTPProxy` (`ingress.type`).
- **Elasticsearch:** requires `vm.max_map_count=262144` and ~6 GB heap / 8 GB container.

See [STORAGE-INVENTORY.md](STORAGE-INVENTORY.md), [NETWORK-INVENTORY.md](NETWORK-INVENTORY.md),
[IMAGE-INVENTORY.md](IMAGE-INVENTORY.md), and [SECRET-INVENTORY.md](SECRET-INVENTORY.md).
