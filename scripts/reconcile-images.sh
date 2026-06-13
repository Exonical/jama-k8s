#!/usr/bin/env bash
#
# reconcile-images.sh — Extract a de-duplicated image inventory from a directory
# of rendered Kubernetes manifests (e.g. the output of kots-pull.sh).
#
# Use the output to populate the `components.*.image` and `images` sections of
# charts/jama-connect/values.yaml, and to fill docs/IMAGE-INVENTORY.md.
#
set -euo pipefail

DIR="${1:-./_kots-rendered}"
[[ -d "$DIR" ]] || { echo "Usage: $(basename "$0") <rendered-manifests-dir>" >&2; exit 1; }

echo "# Image inventory extracted from: $DIR"
echo "# registry/repository:tag"
echo

# Match 'image:' keys in any yaml under the directory, normalize, sort, unique.
grep -rhoE '^[[:space:]]*image:[[:space:]]*"?[^"]+' "$DIR" --include='*.yaml' --include='*.yml' 2>/dev/null \
  | sed -E 's/^[[:space:]]*image:[[:space:]]*//; s/"//g' \
  | grep -vE '^\{\{' \
  | sort -u
