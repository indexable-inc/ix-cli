#!/usr/bin/env bash
# Bumps flake.nix to the latest Ix release: rewrites version + per-platform SRI hashes.
# Run by CI on a schedule. Exits 0 with no changes if already current.
set -euo pipefail

REPO="ix-infrastructure/Ix"
FLAKE="$(dirname "$0")/flake.nix"

latest="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep -m1 '"tag_name"' | cut -d'"' -f4)"
version="${latest#v}"

current="$(grep -m1 'version = "' "$FLAKE" | cut -d'"' -f2)"
if [ "$version" = "$current" ]; then
  echo "Already at $version; nothing to do."
  exit 0
fi
echo "Updating $current -> $version"

# system attr -> release platform string
declare -A PLAT=(
  ["aarch64-darwin"]="darwin-arm64"
  ["x86_64-linux"]="linux-amd64"
  ["aarch64-linux"]="linux-arm64"
)

base="https://github.com/$REPO/releases/download/v$version"
for sys in "${!PLAT[@]}"; do
  p="${PLAT[$sys]}"
  hex="$(curl -fsSL "$base/ix-$version-$p.tar.gz.sha256" | awk '{print $1}')"
  sri="$(nix hash convert --hash-algo sha256 --to sri "$hex")"
  # replace the hash on the line for this system
  sed -i.bak -E "s|(\"$sys\"[[:space:]]*=[[:space:]]*)\"sha256-[^\"]*\"|\1\"$sri\"|" "$FLAKE"
  echo "  $sys -> $sri"
done

# bump version (the single `version = "..."` declaration)
sed -i.bak -E "s|version = \"[^\"]*\"|version = \"$version\"|" "$FLAKE"
rm -f "$FLAKE.bak"

echo "Done. New version: $version"
