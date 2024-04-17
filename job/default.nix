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
  inherit (lib) types mkDefault;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.options) mkOption;

  inherit (import ../internal.nix { inherit lib; }) removeToJSON;
in

{
  options = {
    region = mkOption {
      description = "Region to run job in";
      type = types.str;
      default = "global";
    };

    datacenters = mkOption {
      description = "Datacenters in the region which are eligible for task placement.";
      default = ["*"];
      type = types.listOf types.str;
    };

    namespace = mkOption {
      description = "Namespace to run job in";
      default = "default";
      type = types.str;
    };

    id = mkOption {
      description = "Job ID";
      type = types.str;
    };

    name = mkOption {
      description = "Job name";
      default = config.id;
      type = types.str;
    };

    type = mkOption {
      description = "Scheduler to use for the job.";
      default = "service";
      type = types.enum [
        "service"
        "system"
        "batch"
        "sysbatch"
      ];
    };

    priority = mkOption {
      description = "Scheduling priority.";
      default = 50;
      type = types.ints.between 1 100;
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

    groups = mkOption {
      description = "Task groups.";
      default = {};
      type = types.lazyAttrsOf (types.submodule {
        imports = [ ./group.nix ];
        config.jobType = config.type;
        config.vault = mkDefault (removeToJSON config.vault);
        config.update = mkDefault (removeToJSON config.update);
        config.migrate = mkDefault (removeToJSON config.migrate);
      });
    };

    update = mkOption {
      description = ''
        Default update strategy for groups within the job.
      '';
      default = {};
      type = types.submodule ./update.nix;
    };

    periodic = mkOption {
      description = ''
        Job schedule
      '';
      default = null;
      type = types.nullOr (types.submodule ./periodic.nix);
    };

    migrate = mkOption {
      description = ''
        Default strategy for migrating allocations from draining nodes
        for groups within the job.
      '';
      default = {};
      type = types.submodule ./migrate.nix;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/jobs.go#L867
  config.__toJSON = {
    Region = config.region;
    Datacenters = config.datacenters;
    Namespace = config.namespace;
    ID = config.id;
    Name = config.name;
    Type = config.type;
    Priority = config.priority;
    Constraints = builtins.map (c: c.__toJSON) config.constraints;
    TaskGroups = lib.attrsets.mapAttrsToList (name: c: c.__toJSON name) config.groups;
  } // optionalAttrs (!(builtins.isNull) config.periodic) {
    Periodic = config.periodic.__toJSON;
  };
}
