# Network / service / ingress inventory

> Ports/protocols below are grounded in public Jama self-hosted docs and the chart
> defaults. Confirm against `kots pull` output and adjust
> `components.<name>.ports[]` / `service.ports[]` as needed.

## Services (ClusterIP unless noted)

| Service | Backing workload | Port(s) | Purpose |
| --- | --- | --- | --- |
| `core` | StatefulSet core | 8080/http | main application tier |
| `core-ingress` | StatefulSet core-ingress | 8080/http | inbound request handling |
| `core-jobs` | StatefulSet core-jobs | 8080/http | async/background jobs |
| `core-reports` | StatefulSet core-reports | 8080/http | reporting tier |
| `activemq` | StatefulSet activemq | 61616/openwire, 8161/console | message broker |
| `hazelcast` | StatefulSet hazelcast | 5701/tcp | in-memory data grid |
| `elasticsearch` | StatefulSet elasticsearch | 9200/http, 9300/transport | search/index |
| `elasticsearch-discovery` | StatefulSet elasticsearch | 9300/transport | **headless** peer discovery (`publishNotReadyAddresses`) |
| `search` | Deployment search | 8080/http | search front |
| `diff` | Deployment diff | 8080/http | diff service |
| `saml` | Deployment saml | 8080/http | SAML SSO |
| `oauth` | Deployment oauth | 8080/http | OAuth/OIDC |
| `nginx` | Deployment nginx | 80/http, 443/https | internal reverse proxy (ingress backend) |
| `<name>-headless` | each StatefulSet | same as primary | **headless** governing service (`clusterIP: None`) for stable per-pod DNS (`spec.serviceName`) |

## Ingress

- The external entrypoint targets the **`nginx`** service (`ingress.backendService`,
  `ingress.backendPort: 80`).
- Two modes via `ingress.type`:
  - `ingress` → standard `networking.k8s.io/v1` Ingress (`ingress.className`, e.g. `nginx`).
  - `httpproxy` → Contour `projectcontour.io/v1` HTTPProxy (the appliance default).
- TLS: `ingress.tls.enabled` + `ingress.tls.secretName` (or cert-manager via
  `ingress.annotations`). Extra hostnames via `ingress.extraHosts`.
- Single host by default: `global.fqdn`.

## NetworkPolicy (optional, `networkPolicy.enabled`)

- `default-deny-ingress` for the release pods, plus:
  - allow **intra-namespace** pod-to-pod traffic (the tiers talk to each other),
  - allow ingress to the `nginx` backend from the ingress controller
    (`networkPolicy.allowExternalIngress`).
- Egress to the **external database**, SMTP, and SSO IdP must be permitted by your
  cluster's egress rules (not managed here).

## External egress required

| Destination | From | Why |
| --- | --- | --- |
| External DB (3306/1433) | `core*` | MySQL/MS SQL |
| SMTP relay | `core*` | email (if `smtp.enabled`) |
| SSO IdP (SAML/OIDC) | `saml`/`oauth`, browser | authentication |
| Image registry | nodes/kubelet | image pulls |
| `replicated.app` / `proxy.replicated.com` | operator workstation | `kots pull` only (not at runtime) |
