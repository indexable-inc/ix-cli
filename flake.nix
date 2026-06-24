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
        version = "0-unstable-2026-06-24"; # ix.dev build ffdc10e4df
        hashes = {
          "aarch64-darwin" = "sha256-WtpM4MQUMGT63KxqTeh5CUN0oSfw/qaUs53u8GKiWEw=";
          "x86_64-linux"   = "sha256-QyS5aEJ6ldxpY+AvESWXRLb8mhY/0/jpNXaq4+L9UcQ=";
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
