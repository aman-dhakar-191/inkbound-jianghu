#!/usr/bin/env bash
# Checks next-version.sh against a throwaway git repo with known tags.
set -euo pipefail
script="$(cd "$(dirname "$0")" && pwd)/next-version.sh"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
cd "$dir"
git init -q
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

check() { # bump, expected output
  local got
  got="$("$script" "$1")"
  [[ "$got" == "$2" ]] || { echo "next-version.sh $1: expected '$2', got '$got'" >&2; exit 1; }
}

check patch "0.0.1 1"
check minor "0.1.0 1000"
check major "1.0.0 1000000"

# Highest version wins (numeric, not alphabetical); non-release tags are ignored.
for t in v0.9.0 v0.10.2 v0.2.5 v1.0.0-beta something; do git tag "$t"; done
check patch "0.10.3 10003"
check minor "0.11.0 11000"
check major "1.0.0 1000000"

if "$script" huge 2>/dev/null; then echo "bad bump was accepted" >&2; exit 1; fi
echo "next-version.sh: all checks passed"
