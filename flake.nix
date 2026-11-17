{
  description = "EPIVÍOSI WIKI — Wikipédia et archives ZIM hors-ligne (Kiwix) pour EPIVÍOSI OS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Implémente `epiviosi.wiki.enable` (option déclarée par le socle EPIVÍOSI OS).
      nixosModules.default = import ./module.nix;

      packages.${system} = {
        epiviosi-wiki-setup = pkgs.callPackage ./pkgs/epiviosi-wiki-setup { };
        default = self.packages.${system}.epiviosi-wiki-setup;
      };

      checks.${system} = {
        epiviosi-wiki-setup = self.packages.${system}.epiviosi-wiki-setup;
        # Test en VM : montage à chaud, ajout de ZIM, redémarrage.
        vm = import ./tests/wiki.nix {
          inherit pkgs;
          module = self.nixosModules.default;
        };
      };
    };
}
