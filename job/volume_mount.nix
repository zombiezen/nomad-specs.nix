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
in

{
  options = {
    volume = mkOption {
      description = ''
        Group volume name that the mount is going to access.
      '';
      type = types.str;
    };

    destination = mkOption {
      description = ''
        Path to where the volume should be mounted inside the task's allocation.
      '';
      type = types.str;
    };

    readOnly = mkOption {
      description = ''
        When a group volume is writeable, you may specify that it is read-only
        on a per-mount level.
        If `null`, use the group's `readOnly` value.
      '';
      default = null;
      type = types.nullOr types.bool;
    };

    propagationMode = mkOption {
      description = ''
        Mode for nested volumes:

        - `private` - the task is not allowed to access nested mounts.
        - `host-to-task` - allows new mounts that have been created outside of the task
          to be visible inside the task.
        - `bidirectional` - allows the task to both access new mounts from the host
          and also create new mounts. This mode requires `ReadWrite` permission.
      '';
      default = "private";
      type = types.enum [ "private" "host-to-task" "bidirectional" ];
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/tasks.go#L424-L429
  config.__toJSON = {
    Volume = config.volume;
    Destination = config.destination;
    PropagationMode = config.propagationMode;
  } // optionalAttrs (!(builtins.isNull config.readOnly)) {
    ReadOnly = config.readOnly;
  };
}
