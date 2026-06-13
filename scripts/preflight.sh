#!/usr/bin/env bash
#
# preflight.sh — Cluster readiness checks for deploying Jama Connect into an
# EXISTING Kubernetes cluster (no kURL). These replace a subset of the kURL host
# preflights with cluster-level equivalents. Non-fatal: warnings are advisory.
#
set -uo pipefail

NS="${1:-jama}"
PASS=0; WARN=0; FAIL=0
ok()   { echo "  [OK]   $*"; PASS=$((PASS+1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN+1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo "== Jama Connect preflight (namespace: ${NS}) =="

echo "-- kubectl connectivity"
if kubectl version >/dev/null 2>&1; then ok "kubectl can reach the cluster"; else bad "kubectl cannot reach a cluster"; fi

echo "-- Kubernetes server version (>= 1.25 recommended)"
SV="$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || true)"
if [[ -n "$SV" ]]; then ok "server version: $SV"; else warn "could not determine server version"; fi

echo "-- StorageClasses"
if kubectl get storageclass >/dev/null 2>&1; then
  kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner --no-headers 2>/dev/null | sed 's/^/    /'
  DEF="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"
  if [[ -n "$DEF" ]]; then ok "default StorageClass: $DEF"; else warn "no default StorageClass; set global.storageClass explicitly"; fi
else
  warn "could not list StorageClasses"
fi

echo "-- ReadWriteMany support (required for shared 'tenantfs' PVC)"
warn "Jama needs an RWX-capable StorageClass (NFS/CephFS/EFS/Azure Files) for tenantfs."
echo "       Verify your storage supports ReadWriteMany before install (docs/STORAGE-INVENTORY.md)."

echo "-- vm.max_map_count on nodes (>= 262144 for Elasticsearch)"
warn "Elasticsearch requires vm.max_map_count>=262144 on the nodes it runs on."
echo "       The chart ships a privileged sysctl init container as a fallback"
echo "       (elasticsearch.sysctlInitContainer). Prefer setting it via the node OS"
echo "       or a tuning DaemonSet if privileged containers are disallowed."

echo "-- IngressClass"
if kubectl get ingressclass >/dev/null 2>&1; then
  kubectl get ingressclass -o custom-columns=NAME:.metadata.name,CONTROLLER:.spec.controller --no-headers 2>/dev/null | sed 's/^/    /'
  ok "IngressClass(es) present"
else
  warn "no IngressClass found; install an ingress controller or use ingress.type=httpproxy (Contour)"
fi

echo "-- Prometheus Operator CRDs (optional, for monitoring.serviceMonitor)"
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then ok "ServiceMonitor CRD present"; else warn "ServiceMonitor CRD absent; keep monitoring.serviceMonitor.enabled=false"; fi

echo "-- cert-manager CRDs (optional, for automatic TLS)"
if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then ok "cert-manager CRDs present"; else warn "cert-manager absent; provide ingress.tls.secretName manually"; fi

echo
echo "== Summary: ${PASS} ok, ${WARN} warn, ${FAIL} fail =="
[[ "$FAIL" -eq 0 ]] || { echo "Resolve [FAIL] items before installing."; exit 1; }
