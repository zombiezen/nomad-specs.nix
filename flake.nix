{
  description = "Nomad job specifications using the Nix module system";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      evalJobModules = args: nixpkgs.lib.evalModules (args // {
        modules = [ ./job ] ++ (args.modules or []);
        class = "nomadJob";
      });
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        checks = (pkgs.callPackage ./job/checks.nix { inherit self; }).checks;
      }
    ) // {
      lib = (import ./lib.nix { lib = nixpkgs.lib; }) // {
        evalJobspec = { modules ? [] }:
          let
            evaled = evalJobModules { inherit modules; };
          in {
            Job = evaled.config.__toJSON;
          };
      };
    };
}
