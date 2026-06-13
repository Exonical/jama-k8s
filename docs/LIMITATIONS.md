# Known limitations

## 1. The Jama application is not in the bundle (license required to finish)

The installer tarball contains the **kURL cluster + KOTS console only**. The real
Jama workloads/images are downloaded by kotsadm from `replicated.app` using a
license. Until you run `scripts/kots-pull.sh` with a license (or `.airgap`
bundle), the chart's image references and several workload details are
**`# OPERATOR:` placeholders** and the topology (component names, ports, env,
probes, volume paths) is grounded in **public Jama docs**, not the rendered
manifests. Reconcile per [CONVERSION.md](CONVERSION.md).

## 2. ReadWriteMany storage is required

The shared `tenantfs` volume is mounted by the `core*` tiers and must be
`ReadWriteMany`. Clusters without an RWX StorageClass (e.g. default EBS/GCE PD)
need NFS/CephFS/EFS/Azure Files. Dev single-replica setups can use RWO with one
`core` replica (see `values/dev.yaml`).

## 3. External database only

Jama requires an **external** MySQL 8.0/8.4 or MS SQL Server 2022 with three
databases and ≥300 connections. This chart does **not** deploy a database. Per
Jama docs, **Azure Database, MariaDB, and AWS EKS are not supported**.

## 4. Elasticsearch sysctl

Elasticsearch needs `vm.max_map_count >= 262144`. The chart provides a
**privileged** sysctl init container as a fallback; clusters that forbid
privileged containers must tune nodes via the OS or a dedicated DaemonSet and set
`elasticsearch.sysctlInitContainer=false`.

## 5. KOTS runtime features not reproduced

- Admin console UI, config screens, and in-console updates (replaced by GitOps).
- KOTS/velero snapshots and MinIO object storage (use your backup strategy).
- KOTS preflight/support-bundle collectors (replaced by `scripts/preflight.sh`).
- `repl{{ … }}` runtime secret/cert generation (replaced by operator Secrets or
  Helm functions).

## 6. Kustomize load restrictor

The overlays reference a shared `values/` dir outside each overlay, so
`kustomize build` needs `--enable-helm --load-restrictor LoadRestrictionsNone`.
Argo CD/Flux support this via build options. (Alternatively, copy the env values
file into each overlay dir to avoid the flag.)

## 7. Security contexts are conservative defaults

`podSecurityContext`/`securityContext` defaults are intentionally permissive
(`runAsNonRoot: false`) because the Jama image UID/filesystem expectations are not
yet confirmed from rendered manifests. Tighten these after reconciliation.
