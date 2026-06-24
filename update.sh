#!/usr/bin/env bash
# Re-pins the ix CLI release to the current ix.dev build.
#
# flake.nix fetches the *content-addressed* channel
#   https://ix.dev/cli/<platform>/sha256/<digest>/ix
# which is immutable (a digest URL always serves the same bytes) and whose
# digest IS the binary's sha256. So pinning is just "record the current
# digests" into cli-manifest.json -- flake.nix turns each digest into both the
# fetch URL and its own Nix hash, so a hash mismatch is impossible. No
# `nix store prefetch-file`, no sed hash surgery, nothing to race.
#
# Source of truth is https://ix.dev/cli/manifest.json (written by the ix
# monorepo's publish-cli). Until that is live we fall back to hashing the
# mutable channel binaries directly, so this repo stays self-sufficient.
# Designed to run in CI (Linux). Exits 0 with no change if already current.
set -euo pipefail
cd "$(dirname "$0")"

BASE="https://ix.dev/cli"
platforms=(linux-x86_64 darwin-arm64)

# Prefer the published manifest; fall back to hashing the channel binaries.
if curl -fsSL "$BASE/manifest.json" -o cli-manifest.json.tmp 2>/dev/null \
  && jq -e 'has("linux-x86_64") and has("darwin-arm64")' cli-manifest.json.tmp >/dev/null 2>&1; then
  jq -S . cli-manifest.json.tmp > cli-manifest.json
  rm -f cli-manifest.json.tmp
else
  rm -f cli-manifest.json.tmp
  json='{}'
  for p in "${platforms[@]}"; do
    f="$(mktemp)"
    curl -fsSL "$BASE/$p/ix" -o "$f"
    d="$(sha256sum "$f" | cut -d' ' -f1)"
    json="$(jq --arg p "$p" --arg d "$d" '.[$p] = $d' <<<"$json")"
    rm -f "$f"
  done
  jq -S . <<<"$json" > cli-manifest.json
fi

# Derive a version/rev label from `ix --version` (the Linux binary is
# static-pie, so it runs on the CI runner). Fetch it from the immutable digest
# URL we just pinned. Format: "ix 2026-06-24T18:22:19Z (aa5578d053)".
digest="$(jq -r '."linux-x86_64"' cli-manifest.json)"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
curl -fsSL "$BASE/linux-x86_64/sha256/$digest/ix" -o "$tmp"
chmod +x "$tmp"
ver_line="$("$tmp" --version || true)"
date="$(printf '%s' "$ver_line" | sed -n 's/.*\([0-9]\{4\}-[0-9][0-9]-[0-9][0-9]\)T.*/\1/p')"
rev="$(printf '%s' "$ver_line" | sed -n 's/.*(\([0-9a-f]\{7,\}\)).*/\1/p')"
[ -n "$date" ] || date="$(date -u +%Y-%m-%d)"

sed -i.bak -E \
  "s|version = \"[^\"]*\";.*|version = \"0-unstable-$date\"; # ix.dev build ${rev:-unknown}|" \
  flake.nix
rm -f flake.nix.bak

echo "Pinned ix 0-unstable-$date (${rev:-unknown})"
cat cli-manifest.json
