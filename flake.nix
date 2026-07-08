{
  description = "ix CLI - run anything, anywhere: boot and manage ix VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;

    # Only the platforms ix.dev publishes a binary for.
    # (linux-arm64 "not yet supported", Intel macOS unsupported.)
    systems = ["aarch64-darwin" "x86_64-linux"];
    eachSystem = lib.genAttrs systems;

    # --- managed by update.sh / CI ---
    version = "0-unstable-2026-07-08"; # ix.dev build e8d8045e3d
    # platform -> sha256 content digest of the published `ix` binary.
    # Generated from https://ix.dev/cli/manifest.json. Each digest is BOTH
    # the path segment of the immutable channel URL below AND the binary's
    # own sha256, so the fetch can never hash-mismatch: a republish lands at
    # a new digest/URL and never mutates an existing one, and any pinned rev
    # of this flake stays reproducible forever.
    manifest = lib.importJSON ./cli-manifest.json;
    # --- end managed block ---

    plat = {
      "aarch64-darwin" = "darwin-arm64";
      "x86_64-linux" = "linux-x86_64";
    };

    ixFor = system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {};
        overlays = [];
      };
      digest = manifest.${plat.${system}};
    in
      pkgs.stdenv.mkDerivation {
        pname = "ix";
        inherit version;

        # No compiler runs and no build/host split to leak (a fetched binary
        # is just installed), so strictDeps is a formality here; set it to
        # satisfy the lint.
        strictDeps = true;

        # The official ix.dev installer downloads the same binary from the
        # mutable cli/<platform>/ix key; we fetch the content-addressed copy
        # cli/<platform>/sha256/<digest>/ix instead. It is a self-contained
        # executable (static-pie on Linux), so no patchelf / wrapping needed.
        src = pkgs.fetchurl {
          url = "https://ix.dev/cli/${plat.${system}}/sha256/${digest}/ix";
          sha256 = digest;
        };

        dontUnpack = true;
        dontBuild = true;

        installPhase = ''
          # shell
          runHook preInstall
          install -Dm755 $src $out/bin/ix
          runHook postInstall
        '';

        meta = {
          description = "ix CLI - run anything, anywhere (boot and manage ix VMs)";
          homepage = "https://ix.dev";
          mainProgram = "ix";
          platforms = systems;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
          # License unset: binary redistributed verbatim from ix.dev.
        };
      };
  in {
    packages = eachSystem (system: let
      ix = ixFor system;
    in {
      default = ix;
      ix = ix;
    });
  };
}
