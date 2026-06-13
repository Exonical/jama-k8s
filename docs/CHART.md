# Chart reference — `charts/jama-connect`

A single, component-driven Helm chart. Rather than one template file per workload,
the chart ranges over `.Values.components` and renders a StatefulSet or Deployment
per entry, plus its Service and PVCs. This keeps the topology declarative and easy
to reconcile against `kots pull` output.

## Component schema

```yaml
components:
  <name>:
    enabled: true
    kind: StatefulSet            # or Deployment
    replicas: 1
    image:
      repository: jama/<name>    # OPERATOR: real repo from kots pull
      tag: ""                    # defaults to global.imageTag or .Chart.AppVersion
    ports:
      - name: http
        containerPort: 8080
    service:
      enabled: true
      type: ClusterIP
      headless: false            # true -> clusterIP: None
      ports:
        - { name: http, port: 8080, targetPort: 8080 }
    extraServices:               # optional additional services (e.g. headless discovery)
      - { name: <name>-discovery, headless: true, publishNotReadyAddresses: true, ports: [...] }
    persistence:
      enabled: true
      size: 20Gi
      accessModes: ["ReadWriteOnce"]
      mountPath: /opt/jama/data  # OPERATOR: confirm
      standalone: false          # Deployments set true -> chart-managed PVC volume-<name>-0
      storageClass: ""           # optional per-component override
    mountTenantfs: false         # core* set true -> mount shared RWX tenantfs
    sysctlInitContainer: false   # elasticsearch -> privileged vm.max_map_count init
    resources: {}
    env: []                      # extra env vars (merged after chart-injected env)
    probes:
      liveness: {}
      readiness: {}
```

### PVC naming

StatefulSets use a `volumeClaimTemplate` named `volume`, yielding PVCs
`volume-<name>-<ordinal>` (matching Jama's appliance naming). Deployments with
`persistence.standalone: true` get a chart-managed PVC `volume-<name>-0` and mount
it by that name — so both kinds present identical volume names.

## Top-level value groups

| Group | Purpose |
| --- | --- |
| `global` | registry, imageTag, pullPolicy, imagePullSecrets, storageClass, fqdn |
| `namespace` | optional namespace creation |
| `license` | `existingSecret`, mount path (entitlement) |
| `imagePullSecret` | optional chart-created dockerconfigjson |
| `database` | type (mysql/sqlserver), host, port, db names, `existingSecret` |
| `smtp` | host/port/from/tls/auth + `existingSecret` |
| `sso.saml` / `sso.oidc` | SSO wiring via secrets |
| `elasticsearch` | replicas, heapSize, storageSize, sysctl toggle |
| `sharedStorage.tenantfs` | shared RWX PVC (name/size/accessModes/class/mountPath) |
| `ingress` | type (ingress/httpproxy), className, backend, TLS, hosts |
| `serviceAccount` / `rbac` | SA + minimal Role/RoleBinding |
| `networkPolicy` | default-deny + intra-namespace + frontend allow |
| `monitoring.serviceMonitor` | optional Prometheus Operator ServiceMonitor |
| `podSecurityContext` / `securityContext` | conservative defaults (tighten later) |
| `appConfig` | app tunables surfaced into the ConfigMap |
| `tenantManager` | tenant-provisioning Job (Helm post-install/upgrade hook) |
| `components` | the workload map described above |

## Helpers (`templates/_helpers.tpl`)

`jama.fullname`, `jama.namespace`, `jama.labels`, `jama.componentLabels`,
`jama.image` (registry + tag precedence), `jama.imagePullSecrets`,
`jama.storageClass` (emits `storageClassName` or nothing for cluster-default).

## Render & validate

```bash
helm lint charts/jama-connect
helm template jama charts/jama-connect -n jama -f values/prod.yaml | \
  kubeconform -strict -ignore-missing-schemas -summary
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone overlays/prod
```
