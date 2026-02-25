{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        zig-overlay.url = "github:mitchellh/zig-overlay";
    };

    outputs = { self, nixpkgs, zig-overlay }: let
            system = "x86_64-linux"; 
            pkgs = nixpkgs.legacyPackages.${system};
            zig = zig-overlay.packages.${system}.master;
    in {
        devShells.${system}.default = pkgs.mkShell {
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

        packages.${system}.default = pkgs.stdenv.mkDerivation {
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

    };
}
