# Storage / PVC inventory

All sizes are tunable via values. Per-component PVCs follow StatefulSet naming
`volume-<component>-<ordinal>`. The shared `tenantfs` PVC is **ReadWriteMany**.

> Mount paths marked `# OPERATOR` are assumptions from public Jama docs — confirm
> against `kots pull` output and adjust `components.<name>.persistence.mountPath`.

| PVC | Kind source | Access mode | Default size | values path | Notes |
| --- | --- | --- | --- | --- | --- |
| `volume-core-0` | StatefulSet `core` | RWO | 20Gi | `components.core.persistence.size` | also mounts `tenantfs` |
| `volume-core-ingress-0` | StatefulSet `core-ingress` | RWO | 20Gi | `components.core-ingress.persistence.size` | |
| `volume-core-jobs-0` | StatefulSet `core-jobs` | RWO | 20Gi | `components.core-jobs.persistence.size` | |
| `volume-core-reports-0` | StatefulSet `core-reports` | RWO | 20Gi | `components.core-reports.persistence.size` | |
| `volume-activemq-0` | StatefulSet `activemq` | RWO | 10Gi | `components.activemq.persistence.size` | message broker |
| `volume-hazelcast-0` | StatefulSet `hazelcast` | RWO | 5Gi | `components.hazelcast.persistence.size` | cache/cluster |
| `volume-elasticsearch-{0,1,2}` | StatefulSet `elasticsearch` | RWO | 50Gi | `elasticsearch.storageSize` | one per replica |
| `volume-diff-0` | Deployment `diff` | RWO | 10Gi | `components.diff.persistence.size` | standalone PVC |
| `volume-search-0` | Deployment `search` | RWO | 10Gi | `components.search.persistence.size` | standalone PVC |
| `volume-saml-0` | Deployment `saml` | RWO | 5Gi | `components.saml.persistence.size` | standalone PVC |
| `volume-oauth-0` | Deployment `oauth` | RWO | 5Gi | `components.oauth.persistence.size` | standalone PVC |
| `volume-nginx-0` | Deployment `nginx` | RWO | 5Gi | `components.nginx.persistence.size` | standalone PVC |
| `tenantfs` | shared chart PVC | **RWX** | 100Gi | `sharedStorage.tenantfs.size` | mounted by `core*`; needs NFS/CephFS/EFS/Azure Files |

## StorageClass selection

- `global.storageClass` sets the default for all block PVCs.
- `sharedStorage.tenantfs.storageClass` overrides the class for the RWX volume.
- Per-component override: `components.<name>.persistence.storageClass` (if set).
- Empty string → cluster default StorageClass.

## Persistent data paths (assumptions, confirm via `kots pull`)

- `core*` data: `/opt/jama/data` (`# OPERATOR`)
- shared tenant filesystem: `/mnt/tenantfs` (`sharedStorage.tenantfs.mountPath`)
- Elasticsearch data: `/usr/share/elasticsearch/data` (`# OPERATOR`)
- license: `/etc/jama/license` (`license.mountPath`)
