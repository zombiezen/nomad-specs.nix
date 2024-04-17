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
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.options) mkOption;

  inherit (import ../internal.nix { inherit lib; }) attrTagOption;
in

{
  options = {
    policies = mkOption {
      description = "Set of Vault policies that the task requires.";
      default = [];
      # TODO(soon): Remove duplicates.
      type = types.listOf types.str;
    };

    env = mkOption {
      description = "Specifies if the VAULT_TOKEN and VAULT_NAMESPACE environment variables should be set when starting the task.";
      default = true;
      type = types.bool;
    };

    change = mkOption {
      description = "Behavior Nomad should take if the Vault token changes.";
      default = { restart = true; };
      type = types.attrTag {
        noop = mkOption {
          description = "Take no action (continue running the task) on template change.";
          type = types.enum [ true ];
        };
        restart = mkOption {
          description = "Restart the task on template change.";
          type = types.enum [ true ];
        };
        signal = mkOption {
          description = "Send a configurable signal to the task on template change.";
          type = types.str;
          example = "SIGUSR1";
        };
      };
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L903-L909
  config.__toJSON = {
    Policies = config.policies;
    Env = config.env;
    ChangeMode = attrTagOption config.change;
  } // optionalAttrs (config.change ? signal) {
    ChangeSignal = config.change.signal;
  };
}
