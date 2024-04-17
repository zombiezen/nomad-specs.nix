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

{ lib, ... }:

let
  inherit (lib) types;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.options) mkOption;

  inherit (import ../internal.nix { inherit lib; }) attrTagToJSON;
  nomadLib = import ../lib.nix { inherit lib; };
  nomadTypes = nomadLib.types;

  serviceModule = { config, ... }: {
    options = {
      name = mkOption {
        description = ''
          The name this service will be advertised as in Consul.
          If not supplied, this will default to
          the name of the job, task group, and task
          concatenated together with a dash,
          like `docs-example-server`.
        '';
        default = null;
        type = types.nullOr types.str;
      };

      provider = mkOption {
        description = "Service registration provider to use.";
        default = "consul";
        type = types.enum [ "consul" "nomad" ];
      };

      port = mkOption {
        description = "Port to advertise for this service.";
        default = "";
        type = types.str;
      };

      addressMode = mkOption {
        description = "Specifies which address (host, alloc, or driver-specific) this service should advertise.";
        default = "auto";
        type = types.enum [ "alloc" "auto" "driver" "host" ];
      };

      checks = mkOption {
        description = ''
          Registered checks associated with a service
          into the Nomad or Consul service provider.
        '';
        default = [];
        type = types.listOf checkType;
      };

      tags = mkOption {
        description = "List of tags to associate with this service.";
        default = [];
        type = types.listOf types.str;
      };

      canaryTags = mkOption {
        description = ''
          List of tags to associate with this service
          when the service is part of an allocation that is currently a canary.
        '';
        default = config.tags;
        type = types.listOf types.str;
      };

      __toJSON = mkOption {
        internal = true;
        visible = false;
        readOnly = true;
      };
    };

    # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/services.go#L225-L246
    config.__toJSON = {
      Provider = config.provider;
      PortLabel = config.port;
      AddressMode = config.addressMode;
      Checks = builtins.map attrTagToJSON config.checks;
    } // optionalAttrs (!(builtins.isNull config.name)) {
      Name = config.name;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/services.go#L197-L223
  checkType = types.attrTag {
    tcp = mkOption {
      description = "TCP-based health check.";
      type = types.submodule ({ config, ... }: {
        imports = [
          checkCommon
          checkPortCommon
        ];

        config.__toJSON = {
          Type = "tcp";
          Interval = config.interval;
          Timeout = config.timeout;
          PortLabel = config.port;
          AddressMode = config.addressMode;
        } // optionalAttrs (!(builtins.isNull config.name)) {
          Name = config.name;
        };
      });
    };

    http = mkOption {
      description = "HTTP-based health check.";
      type = types.submodule ({ config, ... }: {
        imports = [
          checkCommon
          checkPortCommon
        ];

        options = {
          method = mkOption {
            description = "HTTP method to use for HTTP checks.";
            default = "GET";
            type = types.str;
          };

          path = mkOption {
            description = "Path of the HTTP endpoint which will be queried to observe the health of a service.";
            type = types.str;
          };

          expose = mkOption {
            description = ''
              Specifies whether an Expose Path should be automatically generated for this check.
              Only compatible with Connect-enabled task-group services
              using the default Connect proxy.
            '';
            default = false;
            type = types.bool;
          };

          protocol = mkOption {
            description = "Protocol for HTTP health check.";
            default = "http";
            type = types.enum [ "http" "https" ];
          };
        };

        config.__toJSON = {
          Type = "http";
          Interval = config.interval;
          Timeout = config.timeout;
          PortLabel = config.port;
          AddressMode = config.addressMode;
          Method = config.method;
          Path = config.path;
          Expose = config.expose;
          Protocol = config.protocol;
        } // optionalAttrs (!(builtins.isNull config.name)) {
          Name = config.name;
        };
      });
    };
  };

  checkCommon = { options = {
    name = mkOption {
      description = "Name of the health check.";
      default = null;
      type = types.nullOr types.str;
    };

    interval = mkOption {
      description = "Frequency of the health checks that Consul or Nomad service provider will perform.";
      type = types.addCheck nomadTypes.duration (x: nomadLib.toDuration x >= nomadLib.toDuration "1s");
    };

    timeout = mkOption {
      description = "How long to wait for a health check query to succeed.";
      type = types.addCheck nomadTypes.duration (x: nomadLib.toDuration x >= nomadLib.toDuration "1s");
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  }; };

  checkPortCommon = { options = {
    port = mkOption {
      description = ''
        Label of the port on which the check will be performed.
        Note this is the label of the port and not the port number
        unless `addressMode = "driver"`.
      '';
      type = types.str;
    };

    addressMode = mkOption {
      description = "Specifies which address (host, alloc, or driver-specific) this check should use.";
      default = "host";
      type = types.enum [ "alloc" "driver" "host" ];
    };
  }; };
in
{ imports = [ serviceModule ]; }
