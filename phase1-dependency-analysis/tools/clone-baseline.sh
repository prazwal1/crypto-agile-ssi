#!/usr/bin/env bash
# Re-creates the pinned Phase 1 baseline. Usage: bash tools/clone-baseline.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/repos"
while IFS=$'\t' read -r repo tag sha _; do
  dest="$root/repos/$repo"
  [ -d "$dest" ] || git clone -q --depth 1 --branch "$tag" "https://github.com/mosip/$repo" "$dest"
  actual="$(git -C "$dest" rev-parse HEAD)"
  [ "$actual" = "$sha" ] || { echo "MISMATCH $repo $tag: $actual != $sha" >&2; exit 1; }
  printf "OK  %-16s %-8s %s\n" "$repo" "$tag" "${sha:0:12}"
done < "$root/manifest.tsv"
