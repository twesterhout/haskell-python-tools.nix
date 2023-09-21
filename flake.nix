{
  description = "twesterhout/haskell-python-tools.nix: Nix functions for Haskell<->Python interop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs: {
    lib = import ./lib.nix { inherit (inputs.nixpkgs) lib; };
  };
}
