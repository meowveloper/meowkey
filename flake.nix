{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        zig-overlay.url = "github:mitchellh/zig-overlay";
    };

    outputs = { self, nixpkgs, zig-overlay }:
        let
            system = "x86_64-linux"; 
            pkgs = nixpkgs.legacyPackages.${system};
            zig = zig-overlay.packages.${system}."0.15.2";
        in {
            devShells.${system}.default = pkgs.mkShell {
                nativeBuildInputs = [
                    zig
                    pkgs.zls
                ];

                shellHook = ''
                    echo "Welcome to the Zig 0.15.2 Dev Shell!"
                '';
            };
        };
}
