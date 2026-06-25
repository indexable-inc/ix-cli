{
  description = "ix CLI - run anything, anywhere: boot and manage ix VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    # Only the platforms ix.dev publishes a binary for.
    # (linux-arm64 "not yet supported", Intel macOS unsupported.)
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # --- managed by update.sh / CI ---
        version = "0-unstable-2026-06-25"; # ix.dev build 2a66dafe17
        # platform -> sha256 content digest of the published `ix` binary.
        # Generated from https://ix.dev/cli/manifest.json. Each digest is BOTH
        # the path segment of the immutable channel URL below AND the binary's
        # own sha256, so the fetch can never hash-mismatch: a republish lands at
        # a new digest/URL and never mutates an existing one, and any pinned rev
        # of this flake stays reproducible forever.
        manifest = builtins.fromJSON (builtins.readFile ./cli-manifest.json);
        # --- end managed block ---

        plat = {
          "aarch64-darwin" = "darwin-arm64";
          "x86_64-linux"   = "linux-x86_64";
        }.${system};

        digest = manifest.${plat};

        ix = pkgs.stdenv.mkDerivation {
          pname = "ix";
          inherit version;

          # The official ix.dev installer downloads the same binary from the
          # mutable cli/<platform>/ix key; we fetch the content-addressed copy
          # cli/<platform>/sha256/<digest>/ix instead. It is a self-contained
          # executable (static-pie on Linux), so no patchelf / wrapping needed.
          src = pkgs.fetchurl {
            url = "https://ix.dev/cli/${plat}/sha256/${digest}/ix";
            # The digest in the URL is the file's sha256, so URL and hash always
            # agree by construction -- no mutable-URL race, no stale pin.
            sha256 = digest;
          };

          dontUnpack = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 $src $out/bin/ix
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "ix CLI - run anything, anywhere (boot and manage ix VMs)";
            homepage = "https://ix.dev";
            mainProgram = "ix";
            platforms = [ "aarch64-darwin" "x86_64-linux" ];
            sourceProvenance = [ sourceTypes.binaryNativeCode ];
            # License unset: binary redistributed verbatim from ix.dev.
          };
        };
      in {
        packages.default = ix;
        packages.ix = ix;
        apps.default = { type = "app"; program = "${ix}/bin/ix"; };
      });
}
