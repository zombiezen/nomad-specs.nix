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

{ config, lib, ... }:

let
  inherit (lib) types;
  inherit (lib.options) mkOption;
in

{
  options = {
    attribute = mkOption {
      description = "Name or reference of the attribute to examine for the constraint.";
      type = types.str;
    };

    value = mkOption {
      description = "The value to compare the attribute against using the specified operation.";
      type = types.str;
    };

    operator = mkOption {
      description = "Comparison operator.";
      default = "=";
      type = types.enum [
        "="
        "!="
        ">"
        ">="
        "<"
        "<="
        "distinct_hosts"
        "distinct_property"
        "regexp"
        "set_contains"
        "set_contains_any"
        "version"
        "semver"
        "is_set"
        "is_not_set"
      ];
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/constraint.go#L16-L21
  config.__toJSON = {
    LTarget = config.attribute;
    RTarget = config.value;
    Operand = config.operator;
  };
}
