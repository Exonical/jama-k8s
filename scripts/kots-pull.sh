#!/usr/bin/env bash
#
# kots-pull.sh — License-respecting extraction of the real Jama Connect manifests.
#
# This is the bridge between this vendor-neutral scaffold and the authoritative,
# licensed Jama application. It runs `kots pull`, which renders the full set of
# Jama Kubernetes manifests + image references LOCALLY using your Jama license —
# WITHOUT installing the KOTS admin console or the kURL cluster.
#
# Licensing is fully preserved: the license file remains the entitlement
# mechanism. This script does not bypass, patch, or remove any license check.
#
# After running, reconcile the rendered output into charts/jama-connect/values.yaml
# (see docs/IMAGE-INVENTORY.md and docs/CONVERSION.md).
#
set -euo pipefail

APP_SLUG="jama-k8s/standardkots"
NAMESPACE="jama"
OUTPUT_DIR="./_kots-rendered"
LICENSE_FILE=""
AIRGAP_BUNDLE=""
SHARED_PASSWORD=""

usage() {
  cat <<EOF
Usage: $(basename "$0") -l <license.yaml> [options]

Required:
  -l, --license-file <path>    Path to your Jama/Replicated license.yaml

Options:
  -a, --airgap-bundle <path>   Path to a Jama .airgap bundle (airgapped installs)
  -n, --namespace <ns>         Target namespace to template for (default: ${NAMESPACE})
  -o, --output-dir <dir>       Where to write rendered manifests (default: ${OUTPUT_DIR})
  -p, --shared-password <pw>   KOTS admin console password (required by 'kots pull')
  -s, --app-slug <slug>        Override app slug (default: ${APP_SLUG})
  -h, --help                   Show this help

Examples:
  # Online (kots downloads the app from replicated.app using the license):
  $(basename "$0") -l license.yaml -n jama -p 'change-me'

  # Airgapped (use a downloaded .airgap bundle):
  $(basename "$0") -l license.yaml -a jama-k8s.airgap -n jama -p 'change-me'
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--license-file)   LICENSE_FILE="$2"; shift 2 ;;
    -a|--airgap-bundle)  AIRGAP_BUNDLE="$2"; shift 2 ;;
    -n|--namespace)      NAMESPACE="$2"; shift 2 ;;
    -o|--output-dir)     OUTPUT_DIR="$2"; shift 2 ;;
    -p|--shared-password) SHARED_PASSWORD="$2"; shift 2 ;;
    -s|--app-slug)       APP_SLUG="$2"; shift 2 ;;
    -h|--help)           usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

err() { echo "ERROR: $*" >&2; exit 1; }

[[ -n "$LICENSE_FILE" ]] || { usage; err "a license file is required (-l)"; }
[[ -f "$LICENSE_FILE" ]] || err "license file not found: $LICENSE_FILE"
[[ -z "$AIRGAP_BUNDLE" || -f "$AIRGAP_BUNDLE" ]] || err "airgap bundle not found: $AIRGAP_BUNDLE"

# Ensure the KOTS kubectl plugin is available.
if ! kubectl kots version >/dev/null 2>&1; then
  cat >&2 <<'EOF'
ERROR: the KOTS CLI (kubectl-kots) is not installed.

Install it with:
  curl https://kots.io/install | bash

(or via krew: kubectl krew install kots). Docs: https://docs.replicated.com/reference/kots-cli-getting-started
EOF
  exit 1
fi

if [[ -z "$SHARED_PASSWORD" ]]; then
  err "'kots pull' requires an admin console password (-p). It is only used to
       template KOTS-internal secrets and is not the Jama application login."
fi

mkdir -p "$OUTPUT_DIR"

echo ">> Rendering Jama Connect manifests for namespace '${NAMESPACE}'"
echo ">> App slug: ${APP_SLUG}"
echo ">> Output:   ${OUTPUT_DIR}"
echo ">> NOTE: this renders manifests locally; it does NOT install KOTS/kURL."

PULL_ARGS=(
  "kots" "pull" "$APP_SLUG"
  "--license-file" "$LICENSE_FILE"
  "--namespace" "$NAMESPACE"
  "--shared-password" "$SHARED_PASSWORD"
  "--rootdir" "$OUTPUT_DIR"
  "--exclude-admin-console"   # we do NOT want the kotsadm console in the output
)
if [[ -n "$AIRGAP_BUNDLE" ]]; then
  PULL_ARGS+=("--airgap-bundle" "$AIRGAP_BUNDLE")
fi

kubectl "${PULL_ARGS[@]}"

echo
echo ">> Done. Rendered manifests are under: ${OUTPUT_DIR}"
echo ">> Next steps:"
echo "   1. Inventory images:   ./scripts/reconcile-images.sh ${OUTPUT_DIR}"
echo "   2. Compare workloads against charts/jama-connect/values.yaml"
echo "   3. See docs/CONVERSION.md for the reconciliation checklist"
echo
echo ">> Reminder: do NOT commit ${OUTPUT_DIR} — it may contain license-derived"
echo "   secrets. It is already covered by .gitignore."
