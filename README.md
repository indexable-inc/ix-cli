# ix-cli

This is the official `ix-cli` binary published at [ix.dev](https://ix.dev) so you
can install it with Nix instead of the `curl https://ix.dev/install.sh | sh`
installer.

The binary is self-contained (static-pie on Linux), so the flake just
fetches it and puts `ix` on your `PATH`.

## Supported platforms

| Nix system       | ix.dev binary   |
| ---------------- | --------------- |
| `aarch64-darwin` | `darwin-arm64`  |
| `x86_64-linux`   | `linux-x86_64`  |

`linux-arm64` is not yet published upstream, and Intel macOS is unsupported - so
neither is offered here.

## Usage

Run without installing:

```sh
nix run github:indexable-inc/ix-cli -- --help
nix run github:indexable-inc/ix-cli -- ls
```

Install into your profile:

```sh
nix profile install github:indexable-inc/ix-cli
```

As a flake input:

```nix
{
  inputs.ix.url = "github:indexable-inc/ix-cli";
  # then use: ix.packages.${system}.default  (or ix.apps.${system}.default)
}
```

## Updating

End users upgrade with `nix profile upgrade ix` or `nix flake update`.

This repository is a generated mirror of the ix monorepo. Every commit is
produced by CI from a build of the CLI; `cli-manifest.json` pins each binary by
its content hash. Pull requests here are closed automatically, so please open
issues instead.

## See also

- [ix CLI docs](https://ix.dev)
