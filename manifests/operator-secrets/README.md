# Operator-provided secrets

Jama Connect requires several secrets that **must be supplied by the operator**.
None of them are committed to this repo. The `*.example.yaml` files here are
**templates with placeholder values** — do not commit a copy with real values.

Preferred ways to create them (no secret ever touches git):

| Secret | Referenced by | Create with |
| --- | --- | --- |
| License | `license.existingSecret` | `kubectl -n jama create secret generic jama-license --from-file=license.yaml=./license.yaml` |
| Database creds | `database.existingSecret` | `kubectl -n jama create secret generic jama-db --from-literal=username=USER --from-literal=password=PASS` |
| SMTP creds | `smtp.existingSecret` | `kubectl -n jama create secret generic jama-smtp --from-literal=username=USER --from-literal=password=PASS` |
| Registry pull | `global.imagePullSecrets[]` | `kubectl -n jama create secret docker-registry jama-registry --docker-server=REGISTRY --docker-username=USER --docker-password=PASS` |
| TLS cert | `ingress.tls.secretName` | `kubectl -n jama create secret tls jama-tls --cert=tls.crt --key=tls.key` (or cert-manager) |
| SAML metadata | `sso.saml.metadataExistingSecret` | `kubectl -n jama create secret generic jama-saml --from-file=metadata.xml=./idp-metadata.xml` |
| OIDC client | `sso.oidc.existingSecret` | `kubectl -n jama create secret generic jama-oidc --from-literal=clientSecret=SECRET` |

## GitOps note

For GitOps (Argo CD / Flux) keep secrets out of git using one of:
- **Sealed Secrets** (Bitnami) — commit encrypted `SealedSecret` CRs.
- **External Secrets Operator** — sync from Vault / AWS Secrets Manager / etc.
- **SOPS** (age/KMS) with Flux's decryption or Argo CD plugins.

The chart only ever references secrets by name (`existingSecret`), so any of the
above works without chart changes.
