# Copyright 2024 Ross Light
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

{
  description = "Nomad job specifications using the Nix module system";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.docs =
          let
            inherit (import ./internal.nix { lib = nixpkgs.lib; }) evalJobModules;
            evaled = evalJobModules {
              modules = [
                { id = "docs"; }
              ];
            };
            doc = pkgs.nixosOptionsDoc {
              options = builtins.removeAttrs evaled.options ["_module"];
            };
          in
            doc.optionsCommonMark;

        checks = (pkgs.callPackage ./job/checks.nix { inherit self; }).checks;
      }
    ) // {
      lib = (import ./lib.nix { lib = nixpkgs.lib; });
    };
}
