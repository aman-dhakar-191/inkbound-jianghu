#!/usr/bin/env bash
# Prints the next version after the highest vX.Y.Z tag, bumped by $1 (patch, minor or major),
# as "<version> <versionCode>". With no tags yet, it starts from 0.0.0.
# versionCode = major * 1000000 + minor * 1000 + patch, so it always grows with the version
# (minor and patch must stay below 1000).
set -euo pipefail

bump="${1:?usage: next-version.sh patch|minor|major}"
latest="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true; } \
  | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
IFS=. read -r major minor patch <<<"${latest:-0.0.0}"

case "$bump" in
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
  *) echo "bump must be patch, minor or major" >&2; exit 1 ;;
esac
if (( minor >= 1000 || patch >= 1000 )); then
  echo "minor and patch must stay below 1000" >&2; exit 1
fi

echo "$major.$minor.$patch $((major * 1000000 + minor * 1000 + patch))"
