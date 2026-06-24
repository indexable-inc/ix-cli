{
  description = "Ix CLI - system intelligence for codebases (prebuilt upstream releases packaged for Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    # Only the platforms upstream actually publishes (no x86_64-darwin, no Windows).
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # --- managed by update.sh / CI: keep these two blocks in sync ---
        version = "0.8.1";
        hashes = {
          "aarch64-darwin" = "sha256-dp6e6wFsb6M6OKuGtTs/L9dF6mGpTLVpStKLL8vcZ0Y=";
          "x86_64-linux"   = "sha256-SYf0gjxyFN6+ndZXFkkbrA77qW6mk1jP50RUeO55b3o=";
          "aarch64-linux"  = "sha256-Qv1HQ4X0JtYYFrpKQG8cc4I9utrRzYtcdfzBqDW82ew=";
        };
        # --- end managed block ---

        plat = {
          "aarch64-darwin" = "darwin-arm64";
          "x86_64-linux"   = "linux-amd64";
          "aarch64-linux"  = "linux-arm64";
        }.${system};

        runtimeDeps = [ pkgs.nodejs_22 pkgs.git pkgs.ripgrep ];

        ix = pkgs.stdenv.mkDerivation {
          pname = "ix";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/ix-infrastructure/Ix/releases/download/v${version}/ix-${version}-${plat}.tar.gz";
            hash = hashes.${system};
          };

          sourceRoot = "ix-${version}-${plat}";

          nativeBuildInputs = [ pkgs.makeWrapper ]
            ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.autoPatchelfHook;

          # autoPatchelf needs libstdc++ for the prebuilt .node native modules on Linux
          buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.stdenv.cc.cc.lib
          ];

          # some prebuilt .node addons dlopen optional libs at runtime; don't fail the build
          autoPatchelfIgnoreMissingDeps = true;
          dontStrip = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/libexec/ix $out/bin
            cp -R . $out/libexec/ix/
            makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/ix \
              --add-flags "$out/libexec/ix/cli/dist/cli/main.js" \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Ix CLI - system intelligence for codebases";
            homepage = "https://github.com/ix-infrastructure/Ix";
            license = licenses.asl20;
            mainProgram = "ix";
            platforms = builtins.attrNames hashes;
            sourceProvenance = [ sourceTypes.binaryNativeCode ];
          };
        };
      in {
        packages.default = ix;
        packages.ix = ix;
        apps.default = { type = "app"; program = "${ix}/bin/ix"; };
      });
}
