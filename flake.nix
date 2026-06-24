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
        version = "0-unstable-2026-06-24"; # ix.dev build f9cf4ed0d0
        hashes = {
          "aarch64-darwin" = "sha256-Ln1yzSdKz5Soq3gsdehcAjrGHMM2MGFDy1f3S1ptG/Q=";
          "x86_64-linux"   = "sha256-IrN/VU8/qjEQPzJIyGqofrmk0LZX7gZLKu8tmXunL44=";
        };
        # --- end managed block ---

        plat = {
          "aarch64-darwin" = "darwin-arm64";
          "x86_64-linux"   = "linux-x86_64";
        }.${system};

        ix = pkgs.stdenv.mkDerivation {
          pname = "ix";
          inherit version;

          # The official ix.dev installer downloads this exact binary.
          # It is a self-contained executable (static-pie on Linux), so no
          # patchelf / wrapping is needed.
          src = pkgs.fetchurl {
            url = "https://ix.dev/cli/${plat}/ix";
            hash = hashes.${system};
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
            platforms = builtins.attrNames hashes;
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
