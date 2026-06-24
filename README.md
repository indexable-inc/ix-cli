# ix-cli

Nix flake that packages the [Ix CLI](https://github.com/ix-infrastructure/Ix) -
"system intelligence for codebases" - from its official prebuilt GitHub releases,
so you can install it with Nix instead of the `curl | sh` installer.

This repackages upstream's signed release tarballs verbatim (Apache-2.0). The CLI
is a self-contained Node app; this flake just wraps its launcher with `node`,
`git`, and `ripgrep` on `PATH`.

## Supported platforms

| Nix system       | Upstream asset    |
| ---------------- | ----------------- |
| `aarch64-darwin` | `darwin-arm64`    |
| `x86_64-linux`   | `linux-amd64`     |
| `aarch64-linux`  | `linux-arm64`     |

Intel macOS (`x86_64-darwin`) and Windows are not published upstream, so they are
not offered here.

## Usage

Run without installing:

```sh
nix run github:indexable-inc/ix-cli -- --help
```

Install into your profile:

```sh
nix profile install github:indexable-inc/ix-cli
```

As a flake input:

```nix
{
  inputs.ix.url = "github:indexable-inc/ix-cli";
  # then use: ix.packages.${system}.default
}
```

## Updating

End users upgrade with `nix profile upgrade ix` or `nix flake update`.

This repo tracks new Ix releases automatically: a daily GitHub Action runs
[`update.sh`](./update.sh), which reads the latest release tag, pulls the per
-platform `.sha256` sidecars, converts them to SRI, rewrites `flake.nix`, and
opens a PR. Run it manually with:

```sh
./update.sh
```

## Note

Unofficial community packaging. Not affiliated with the Ix maintainers.
