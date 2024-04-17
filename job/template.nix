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
  nomadTypes = (import ../lib.nix { inherit lib; }).types;
in

{
  options = {
    destination = mkOption {
      description = "Specifies the location where the resulting template should be rendered, relative to the task working directory.";
      type = types.str;
    };

    source = mkOption {
      description = "Specifies the template to execute.";
      type = types.attrTag {
        data = mkOption {
          description = "The raw template to execute.";
          type = types.str;
        };
        path = mkOption {
          description = "The path to the template to execute.";
          type = types.str;
        };
      };
    };

    splay = mkOption {
      description = "Nomad will wait a random amount of time between 0 ms and the given value before invoking the change mode. Used to prevent a thundering herd problem where all task instances restart at the same time.";
      default = "5s";
      type = nomadTypes.duration;
    };

    perms = mkOption {
      description = "Rendered template's file permissions";
      default = "0644";
      type = types.strMatching "[0-7]{3,4}";
    };

    uid = mkOption {
      description = "Rendered template owner's user ID. If null, the ID of the Nomad agent user will be used.";
      default = null;
      type = types.nullOr types.ints.unsigned;
    };

    gid = mkOption {
      description = "Rendered template owner's group ID. If null, the ID of the Nomad agent group will be used.";
      default = null;
      type = types.nullOr types.ints.unsigned;
    };

    leftDelimiter = mkOption {
      description = "The left delimiter to use in the template.";
      default = "{{";
      type = types.str;
    };

    rightDelimiter = mkOption {
      description = "The right delimiter to use in the template.";
      default = "}}";
      type = types.str;
    };

    env = mkOption {
      description = "If true, the template should be read back in as environment variables for the task.";
      default = false;
      type = types.bool;
    };

    errorOnMissingKey = mkOption {
      description = ''
        If `true`, when the template attempts to index a map key that does not exist,
        the template engine will return an error, which will cause the task to fail.

        If `false`, the template engine will do nothing and continue executing the template.
        If printed, the result of the index operation is the string `<no value>`.
      '';
      default = false;
      type = types.bool;
    };

    change = mkOption {
      description = "Behavior Nomad should take if the rendered template changes.";
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
          type = types.string;
          example = "SIGUSR1";
        };
        script = mkOption {
          description = "Run a script on template change.";
          type = types.submodule {
            options.command = mkOption {
              description = "Full path to a script or executable that is to be executed on template change. The command must return exit code 0 to be considered successful. Path is relative to the driver, e.g., if running with a container driver the path must be existing in the container.";
              type = types.str;
            };

            options.args = mkOption {
              description = "List of arguments that are passed to the script that is to be executed on template change.";
              default = [];
              type = types.listOf types.str;
            };

            options.timeout = mkOption {
              description = "Timeout for script execution.";
              default = "5s";
              type = nomadTypes.duration;
            };

            options.failOnError = mkOption {
              description = "If true, Nomad will kill the task if the script execution fails. If false, script failure will be logged but the task will continue uninterrupted.";
              default = false;
              type = types.bool;
            };
          };
        };
      };
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L834-L851
  config.__toJSON = {
    DestPath = config.destination;
    ChangeMode = attrTagOption config.change;
    Splay = config.splay;
    Perms = config.perms;
    LeftDelim = config.leftDelimiter;
    RightDelim = config.rightDelimiter;
    Envvars = config.env;
    ErrMissingKey = config.errorOnMissingKey;
  } // optionalAttrs (config.source ? data) {
    EmbeddedTmpl = config.source.data;
  } // optionalAttrs (config.source ? path) {
    SourcePath = config.source.path;
  } // optionalAttrs (config.change ? signal) {
    ChangeSignal = config.change.signal;
  } // optionalAttrs (config.change ? script) {
    ChangeScript = let cfg = config.change.script; in {
      Command = cfg.command;
      Args = cfg.args;
      Timeout = cfg.timeout;
      FailOnError = cfg.failOnError;
    };
  } // optionalAttrs (!(builtins.isNull config.uid)) {
    Uid = config.uid;
  } // optionalAttrs (!(builtins.isNull config.gid)) {
    Gid = config.gid;
  };
}
