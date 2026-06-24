#!/usr/bin/env bash
# Re-pins flake.nix to the current ix.dev CLI binaries.
# ix.dev/cli/<platform>/ix is an unversioned "latest" URL, so we pin by content
# hash and refresh whenever the binary changes. Designed to run in CI (Linux).
# Exits 0 with no change if already current.
set -euo pipefail

FLAKE="$(dirname "$0")/flake.nix"
BASE="https://ix.dev/cli"

# Nix system attr -> ix.dev platform string
declare -A PLAT=(
  ["aarch64-darwin"]="darwin-arm64"
  ["x86_64-linux"]="linux-x86_64"
)

changed=0
for sys in "${!PLAT[@]}"; do
  p="${PLAT[$sys]}"
  sri="$(nix store prefetch-file --json "$BASE/$p/ix" | sed -n 's/.*"hash":"\([^"]*\)".*/\1/p')"
  cur="$(grep -E "\"$sys\"[[:space:]]*=[[:space:]]*\"sha256-" "$FLAKE" | sed -n 's/.*"\(sha256-[^"]*\)".*/\1/p')"
  if [ "$sri" != "$cur" ]; then
    changed=1
    echo "  $sys: $cur -> $sri"
  fi
  sed -i.bak -E "s|(\"$sys\"[[:space:]]*=[[:space:]]*)\"sha256-[^\"]*\"|\1\"$sri\"|" "$FLAKE"
done

if [ "$changed" = 0 ]; then
  echo "Already current; nothing to do."
  rm -f "$FLAKE.bak"
  exit 0
fi

# Derive a version/rev label from `ix --version` (Linux binary is static-pie, so
# it runs on the CI runner). Format: "ix 2026-06-24T18:22:19Z (aa5578d053)".
tmp="$(mktemp)"
curl -fsSL "$BASE/linux-x86_64/ix" -o "$tmp"
chmod +x "$tmp"
ver_line="$("$tmp" --version || true)"
date="$(printf '%s' "$ver_line" | sed -n 's/.*\([0-9]\{4\}-[0-9][0-9]-[0-9][0-9]\)T.*/\1/p')"
rev="$(printf '%s' "$ver_line" | sed -n 's/.*(\([0-9a-f]\{7,\}\)).*/\1/p')"
rm -f "$tmp"

if [ -n "$date" ]; then
  sed -i.bak -E "s|version = \"[^\"]*\";.*|version = \"0-unstable-$date\"; # ix.dev build ${rev:-unknown}|" "$FLAKE"
fi
rm -f "$FLAKE.bak"

echo "Updated to 0-unstable-${date:-?} (${rev:-?})"
