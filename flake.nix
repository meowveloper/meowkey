{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        zig-overlay.url = "github:mitchellh/zig-overlay";
    };

    outputs = { self, nixpkgs, zig-overlay }: let
        systems = [ "x86_64-linux" "aarch64-linux" ];
        forEachSystem = nixpkgs.lib.genAttrs systems;
    in {
        devShells = forEachSystem (system: let
            pkgs = nixpkgs.legacyPackages.${system};
            zig = zig-overlay.packages.${system}."0.16.0";
        in {
            default = pkgs.mkShell {
                nativeBuildInputs = [
                    zig
                    pkgs.zls
                    pkgs.pkg-config
                    pkgs.ffmpeg
                ];

                buildInputs = [
                    pkgs.alsa-lib
                ];

                shellHook = ''
                    echo "Welcome to meowkey Dev Shell!"
                '';
            };
        });

        packages = forEachSystem (system: let
            pkgs = nixpkgs.legacyPackages.${system};
            zig = zig-overlay.packages.${system}."0.16.0";
        in {
            default = pkgs.stdenv.mkDerivation {
                name = "meowkey";
                src = ./.; 
                nativeBuildInputs = [
                    zig
                    pkgs.pkg-config
                    pkgs.autoPatchelfHook
                ];
                buildInputs = [
                    pkgs.alsa-lib
                ];
                dontConfigure = true;
                buildPhase = ''
                    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
                    export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local-cache
                    mkdir -p $ZIG_GLOBAL_CACHE_DIR $ZIG_LOCAL_CACHE_DIR
                    zig build -Doptimize=ReleaseSafe --prefix $out --global-cache-dir $ZIG_GLOBAL_CACHE_DIR
                '';
                dontInstall = true;
            };
        });
    };
}
