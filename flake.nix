{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        zig-overlay.url = "github:mitchellh/zig-overlay";
    };

    outputs = { self, nixpkgs, zig-overlay }:
        let
            system = "x86_64-linux"; 
            pkgs = nixpkgs.legacyPackages.${system};
            zig = zig-overlay.packages.${system}.master;
        in {
            devShells.${system}.default = pkgs.mkShell {
                nativeBuildInputs = [
                    zig
                    pkgs.zls
                    pkgs.pkg-config
                ];

                buildInputs = [
                    pkgs.alsa-lib
                ];

                shellHook = ''
                    echo "Welcome to meowkey Dev Shell!"
                '';
            };
        };
}
