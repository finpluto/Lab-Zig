{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv/v1.4.1";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devenv.flakeModule
      ];
      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: {
        devenv.shells.default = {
          packages = with pkgs; [
            SDL2
          ];
          languages.zig = {
            enable = true;
            package = inputs'.zig.packages."0.14.0";
          };
        };
      };
    };
}
