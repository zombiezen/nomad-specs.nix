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
  inherit (lib) types mkDefault mkIf;
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.lists) optional;
  inherit (lib.options) mkOption;

  inherit (import ../internal.nix { inherit lib; }) attrTagToJSON removeToJSON;
in

{
  options = {
    count = mkOption {
      description = "Number of instances that should be running under for this group.";
      type = types.ints.unsigned;
      default = 1; # TODO(someday): Consult scaling block too.
    };

    constraints = mkOption {
      description = "Restrictions on nodes which are eligible for task placement.";
      default = [];
      type = types.listOf (types.submodule ./constraint.nix);
    };

    vault = mkOption {
      description = "Vault token configuration.";
      default = null;
      type = types.nullOr (types.submodule ./vault.nix);
    };

    services = mkOption {
      description = ''
        Specifies integrations with Nomad or Consul for service discovery.
        Nomad automatically registers each service when an allocation is started
        and de-registers them when the allocation is destroyed.
      '';
      default = [];
      type = types.listOf (types.submodule ./service.nix);
    };

    network = mkOption {
      description = ''
        Network requirements and configuration,
        including static and dynamic port allocations, for the group.
      '';
      default = null;
      type = types.nullOr (types.submodule ./network.nix);
    };

    tasks = mkOption {
      description = "One or more tasks to run within this group.";
      type = types.lazyAttrsOf (types.submodule {
        imports = [ ./task.nix ];
        config.vault = mkDefault (removeToJSON config.vault);
        config.restart = mkIf (!(builtins.isNull config.restart)) (mkDefault (removeToJSON config.restart));
        config.jobType = config.jobType;
      });
    };

    volumes = mkOption {
      description = ''
        Volumes required by tasks within the group.
      '';
      default = {};
      type = types.attrsOf (import ./volume.nix { inherit lib; });
    };

    ephemeralDisk = mkOption {
      description = ''
        Ephemeral disk requirements of the group.
        All tasks in this group will share the same ephemeral disk.
      '';
      default = {};
      type = types.submodule ({ config, ... }: {
        options.migrate = mkOption {
          description = ''
            If `true`, indicates that the Nomad client
            should make a best-effort attempt to migrate the data from the previous allocation,
            even if the previous allocation was on another client.
          '';
          default = false;
          type = types.bool;
        };

        options.size = mkOption {
          description = "Size of the ephemeral disk in MiB.";
          default = 300;
          type = types.ints.unsigned;
        };

        options.sticky = mkOption {
          description = ''
            If `true`, indicates that Nomad should make a best-effort attempt
            to place the updated allocation on the same machine.
          '';
          default = config.migrate;
          type = types.bool;
        };
      });
    };

    update = mkOption {
      description = ''
        Update strategy.
      '';
      default = {};
      type = types.submodule ./update.nix;
    };

    migrate = mkOption {
      description = ''
        Group's strategy for migrating allocations from draining nodes.
      '';
      default = {};
      type = types.submodule ./migrate.nix;
    };

    restart = mkOption {
      description = ''
        Default behavior for failure in the group's tasks.
      '';
      default = null;
      type = types.nullOr (types.submodule ./restart.nix);
    };

    jobType = mkOption {
      internal = true;
      type = types.str;
      visible = false;
      readOnly = true;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L433-L455
  config.__toJSON = name: {
    Name = name;
    Count = config.count;
    Constraints = builtins.map (c: c.__toJSON) config.constraints;
    Services = builtins.map (s: s.__toJSON) config.services;
    Tasks = lib.attrsets.mapAttrsToList (name: c: c.__toJSON name) config.tasks;
    Volumes = mapAttrs (name: value: attrTagToJSON value name) config.volumes;
    Update = config.update.__toJSON;
    Migrate = config.migrate.__toJSON;
    Networks = optional (!(builtins.isNull config.network)) config.network.__toJSON;

    # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L308-L313
    EphemeralDisk = let c = config.ephemeralDisk; in {
      Sticky = c.sticky;
      Migrate = c.migrate;
      SizeMB = c.size;
    };
  };
}
