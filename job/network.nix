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
  inherit (lib.attrsets) mapAttrsToList optionalAttrs;
  inherit (lib.options) mkOption;

  networkResource = { config, ...}: {
    options = {
      mode = mkOption {
        description = ''
          Mode of the network.
          This option is only supported on Linux clients.
        '';
        default = "host";
        type = types.either
          (types.enum [
            "none"
            "bridge"
            "host"
          ])
          (types.strMatching "cni/.+");
      };

      ports = mkOption {
        description = ''
          Specifies TCP/UDP port allocations.
        '';
        default = {};
        type = types.attrsOf (types.submodule port);
      };

      hostname = mkOption {
        description = ''
          The hostname assigned to the network namespace.
          This is currently only supported using the Docker driver
          and when the mode is set to `bridge`.
          This parameter supports interpolation.
        '';
        default = "";
        type = types.str;
      };

      dns = mkOption {
        description = ''
          Sets the DNS configuration for the allocations.
          By default all task drivers will inherit DNS configuration from the client host.
          DNS configuration is only supported on Linux clients at this time.
          Note that if you are using a CNI `mode`,
          these values will override any DNS configuration the CNI plugins return.
        '';
        default = {};
        type = types.submodule dnsConfig;
      };

      __toJSON = mkOption {
        internal = true;
        visible = false;
        readOnly = true;
      };
    };

    # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/resources.go#L149-L164
    config.__toJSON = {
      Mode = config.mode;
      DynamicPorts = mapAttrsToList (name: p: p.__toJSON name) config.ports;
    } // optionalAttrs (config.hostname != "") {
      Hostname = config.hostname;
    } // optionalAttrs (!config.dns.__empty) {
      DNS = config.dns.__toJSON;
    };
  };

  port = { config, ...}: {
    options = {
      static = mkOption {
        description = ''
          Static TCP/UDP port to allocate.
          If zero, a dynamic port is chosen.
          The Nomad developers do not recommend using static ports,
          except for system or specialized jobs like load balancers.
        '';
        default = 0;
        type = types.ints.u16;
      };

      to = mkOption {
        description = ''
          Applicable when using "bridge" mode to configure port to map to
          inside the task's network namespace.
          Omitting this field or setting it to -1 sets the mapped port equal to the dynamic port allocated by the scheduler.
          The `NOMAD_PORT_<label>` environment variable will contain the `to` value.
        '';
        default = -1;
        type = types.int;
      };

      hostNetwork = mkOption {
        description = ''
          Designates the host network name to use when allocating the port.
          When port mapping the host port will only forward traffic
          to the matched host network address.
        '';
        default = "";
        type = types.str;
      };

      __toJSON = mkOption {
        internal = true;
        visible = false;
        readOnly = true;
      };
    };

    # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/resources.go#L134-L139
    config.__toJSON = name: {
      Label = name;
    } // optionalAttrs (config.static == 0) {
      Value = config.static;
    } // optionalAttrs (config.to > 0) {
      To = config.to;
    } // optionalAttrs (config.hostNetwork != "") {
      HostNetwork = config.hostNetwork;
    };
  };

  dnsConfig = { config, ... }: {
    options = {
      servers = mkOption {
        description = ''
          DNS nameservers the allocation uses for name resolution.
        '';
        default = [];
        type = types.listOf types.str;
      };

      searches = mkOption {
        description = ''
          Search list for hostname lookup.
        '';
        default = [];
        type = types.listOf types.str;
      };

      options = mkOption {
        description = ''
          Internal resolver variables.
        '';
        default = [];
        type = types.listOf types.str;
      };

      __empty = mkOption {
        internal = true;
        visible = false;
        readOnly = true;
      };

      __toJSON = mkOption {
        internal = true;
        visible = false;
        readOnly = true;
      };
    };

    config.__empty =
      config.servers == [] &&
      config.searches == [] &&
      config.options == [];

    # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/resources.go#L141-L145
    config.__toJSON = {
      Servers = config.servers;
      Searches = config.searches;
      Options = config.options;
    };
  };
in
{ imports = [ networkResource ]; }
