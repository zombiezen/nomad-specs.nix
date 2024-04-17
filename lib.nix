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

{ lib }:

rec {
  toDuration = x:
    if builtins.isInt x then x
    else if builtins.isString x then
      let
        inherit (lib.strings) escapeNixString;
        signAndRest = builtins.match "([-+]?)(.*)" x;
        sign = builtins.elemAt signAndRest 0;
        rest = builtins.elemAt signAndRest 1;
        signScale = if sign == "-" then -1 else 1;
        multipliers =
          let
            us = 1000;
            s = 1000000000;
          in {
            ns = 1;
            inherit us;
            "µs" = us; # U+00B5 = micro symbol
            "μs" = us; # U+03BC = Greek letter mu
            ms = 1000 * us;
            inherit s;
            m = 60 * s;
            h = 60 * 60 * s;
          };
        parse = s:
          if s == "" then 0
          else let
            m = builtins.match "([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([^.0-9]+)(.*)" s;
          in
            if builtins.isNull m then throw "invalid duration ${escapeNixString x}"
            else let
              n = builtins.elemAt m 0;
              n' =
                if lib.strings.hasPrefix "." n then "0" + n
                else n;
              unit = builtins.elemAt m 2;
              rest = builtins.elemAt m 3;
              mul = multipliers.${unit} or (throw "unknown unit ${escapeNixString unit} in duration ${escapeNixString x}");
            in
              (builtins.floor ((builtins.fromJSON n') * mul)) + (parse rest);
      in
        if rest == "" then throw "invalid duration ${escapeNixString x}"
        else if rest == "0" then 0
        else signScale * (parse rest)
    else
      throw "cannot convert to duration from ${builtins.typeOf x}";

  types.duration = lib.types.coercedTo (lib.types.str // {
    name = "duration";
    description = "duration string";
    descriptionClass = "noun";
  }) toDuration lib.types.int;
}
