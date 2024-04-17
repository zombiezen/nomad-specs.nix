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
  inherit (lib) literalMD types;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.options) mkOption;
in

{
  options = {
    driver = mkOption {
      description = "Task driver that should be used to run the task.";
      type = types.str;
    };

    config = mkOption {
      description = "Driver task configuration.";
      type = types.attrsOf types.anything;
      default = {};
    };

    constraints = mkOption {
      description = "Restrictions on nodes which are eligible for task placement.";
      default = [];
      type = types.listOf (types.submodule ./constraint.nix);
    };

    env = mkOption {
      description = "Environment variables that will be passed to the running process.";
      default = null;
      type = types.nullOr (types.attrsOf types.str);
    };

    services = mkOption {
      description = ''
        Specifies integrations with Nomad or Consul for service discovery.
        Nomad automatically registers when a task is started
        and de-registers it when the task dies.
      '';
      default = [];
      type = types.listOf (types.submodule ./service.nix);
    };

    resources = mkOption {
      description = "Minimum resource requirements such as RAM, CPU, and devices.";
      default = {};
      type = types.submodule ./resources.nix;
    };

    restart = mkOption {
      description = ''
        Behavior for task failure.
        Restarts happen on the client that is running the task.
      '';
      default =
        if config.jobType == "batch" then { attempts = 3; interval = "24h"; }
        else { attempts = 2; interval = "30m"; };
      defaultText = literalMD ''
        For batch jobs: `{ attempts = 3; interval = "24h"; }`.
        For all other jobs: `{ attempts = 2; interval = "30m"; }`.
      '';
      type = types.submodule ./restart.nix;
    };

    logs = mkOption {
      description = ''
        Configures the log rotation policy for a task's stdout and stderr.
      '';
      default = {};
      type = types.submodule {
        options.enabled = mkOption {
          description = "Whether logs are collected for this task.";
          default = true;
          type = types.bool;
        };

        options.maxFiles = mkOption {
          description = ''
            Specifies the maximum number of rotated files Nomad will retain for stdout and stderr.
            Each stream is tracked individually,
            so specifying a value of 2 will create 4 files:
            2 for stdout and 2 for stderr.
          '';
          default = 10;
          type = types.ints.unsigned;
        };

        options.maxFileSize = mkOption {
          # Source for units: https://github.com/hashicorp/nomad/blob/f45244154288eec153eb4fd5969b66f94e62308e/client/logmon/logmon.go#L141
          description = ''
            Specifies the maximum size of each rotated file in MiB.
            If the amount of disk resource requested for the task
            is less than the total amount of disk space
            needed to retain the rotated set of files,
            Nomad will return a validation error when a job is submitted.
          '';
          default = 10;
          type = types.ints.unsigned;
        };
      };
    };

    templates = mkOption {
      description = "Set of templates to render for the task.";
      default = [];
      type = types.listOf (types.submodule ./template.nix);
    };

    vault = mkOption {
      description = "Vault token configuration.";
      default = null;
      type = types.nullOr (types.submodule ./vault.nix);
    };

    volumeMounts = mkOption {
      description = ''
        Where to mount group volumes.
      '';
      default = [];
      type = types.listOf (types.submodule ./volume_mount.nix);
    };

    csiPlugin = mkOption {
      description = "Specify the task provides a Container Storage Interface plugin to the cluster.";
      default = null;
      type = types.nullOr (types.submodule ./csi_plugin.nix);
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

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L680-L706
  config.__toJSON = name: {
    Name = name;
    Driver = config.driver;
    Config = config.config;
    Constraints = builtins.map (c: c.__toJSON) config.constraints;
    Env = config.env;
    Services = builtins.map (s: s.__toJSON) config.services;
    Resources = config.resources.__toJSON;
    RestartPolicy = config.restart.__toJSON;
    LogConfig =
      if !config.logs.enabled then { disabled = true; }
      else {
        MaxFiles = config.logs.maxFiles;
        MaxFileSizeMB = config.logs.maxFileSize;
      };
    Templates = builtins.map (t: t.__toJSON) config.templates;
    Vault = config.vault.__toJSON or null;
    VolumeMounts = builtins.map (m: m.__toJSON) config.volumeMounts;
  } // optionalAttrs (!(builtins.isNull config.csiPlugin)) {
    CSIPluginConfig = config.csiPlugin.__toJSON;
  };
}
