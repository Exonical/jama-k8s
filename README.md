# jama-k8s — vendor-neutral Jama Connect for Kubernetes

Convert the Jama Connect **KOTS/kURL** installer into a clean, GitOps-ready
deployment (Helm + Kustomize) that runs in an **existing** Kubernetes cluster —
without the KOTS admin console or the kURL cluster installer — while fully
preserving Jama's licensing/entitlement mechanism.

> **Status / important:** the upstream installer bundle ships the **cluster
> installer only**; the Jama application images/manifests are downloaded at
> install time from `replicated.app` using your **license**. Until you render
> them with a valid license (see below), image references and some workload
> details are `# OPERATOR:` placeholders grounded in Jama's public docs.
> See [docs/ANALYSIS.md](docs/ANALYSIS.md) and [docs/LIMITATIONS.md](docs/LIMITATIONS.md).

## Layout

```
jama-k8s/
├── charts/jama-connect/      # component-driven Helm chart (the base)
├── manifests/                # raw namespace + operator-secret TEMPLATES (no real secrets)
│   ├── base/
│   └── operator-secrets/
├── overlays/{dev,staging,prod}/   # Kustomize wrappers (kustomize build --enable-helm)
├── values/{dev,staging,prod}.yaml # per-env Helm values (single source of truth)
├── scripts/                  # kots-pull.sh (license render), reconcile-images.sh, preflight.sh
├── docs/                     # analysis, conversion map, install/upgrade/uninstall, inventories
└── README.md
```

## Quick start

```bash
# 0. Check the cluster
./scripts/preflight.sh jama

# 1. Render the REAL Jama manifests with your license (preserves entitlement)
./scripts/kots-pull.sh -l license.yaml -n jama -p '<console-pw>'
./scripts/reconcile-images.sh ./_kots-rendered   # -> fill docs/IMAGE-INVENTORY.md + values

# 2. Create operator secrets (license, db, registry, tls, ...)
#    see manifests/operator-secrets/README.md

# 3a. Install with Helm
helm upgrade --install jama charts/jama-connect -n jama --create-namespace -f values/prod.yaml

# 3b. Or render via Kustomize for Argo CD / Flux
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone overlays/prod | kubectl apply -f -
```

Full steps: [docs/INSTALL.md](docs/INSTALL.md).

## What this is (and isn't)

- **Is:** a production-grade chart encoding Jama's self-hosted topology (core tiers,
  ActiveMQ, Hazelcast, Elasticsearch, SAML/OAuth, diff/search, internal nginx,
  tenant-manager Job), external-DB ready, RWX shared storage, ingress (NGINX or
  Contour HTTPProxy), RBAC, NetworkPolicy, optional ServiceMonitor — all
  configurable, no hardcoded secrets.
- **Isn't:** a re-distribution of Jama's proprietary images/manifests, and it does
  **not** remove or weaken licensing/authentication. The license remains the
  entitlement mechanism; images come from your licensed registry.

## Docs

| Doc | |
| --- | --- |
| [ANALYSIS.md](docs/ANALYSIS.md) | bundle breakdown: KOTS vs kURL vs plain-K8s vs Jama |
| [CONVERSION.md](docs/CONVERSION.md) | KOTS/kURL removal+replacement map; reconciliation checklist |
| [CHART.md](docs/CHART.md) | chart/component schema and values reference |
| [INSTALL.md](docs/INSTALL.md) / [UNINSTALL.md](docs/UNINSTALL.md) / [UPGRADE.md](docs/UPGRADE.md) | lifecycle (non-KOTS) |
| [IMAGE](docs/IMAGE-INVENTORY.md) / [SECRET](docs/SECRET-INVENTORY.md) / [STORAGE](docs/STORAGE-INVENTORY.md) / [NETWORK](docs/NETWORK-INVENTORY.md) | inventories |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | known limitations & assumptions |

## Validation

`helm lint`, `helm template … | kubeconform`, and
`kustomize build --enable-helm` for all three overlays pass. See
[CHART.md](docs/CHART.md#render--validate).
