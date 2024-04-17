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

  nomadTypes = (import ../lib.nix { inherit lib; }).types;
in

{
  options = {
    id = mkOption {
      description = "ID for the plugin.";
      type = types.str;
    };

    type = mkOption {
      description = "Each Nomad client node where you want to mount a volume will need a node plugin instance. Some plugins will also require one or more controller plugin instances to communicate with the storage provider's APIs. Some plugins can serve as both controller and node at the same time, and these are called monolith plugins. Refer to your CSI plugin's documentation.";
      type = types.enum [
        "node"
        "controller"
        "monolith"
      ];
    };

    mountDir = mkOption {
      description = "The directory path inside the container where the plugin will expect a Unix domain socket for bidirectional communication with Nomad.";
      default = "/csi";
      type = types.str;
    };

    stagePublishBaseDir = mkOption {
      description = "The base directory path inside the container where the plugin will be instructed to stage and publish volumes.";
      default = "/local/csi";
      type = types.str;
    };

    healthTimeout = mkOption {
      description = "The duration that the plugin supervisor will wait before restarting an unhealthy CSI plugin.";
      default = "30s";
      type = nomadTypes.duration;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L1076-L1098
  config.__toJSON = {
    ID = config.id;
    Type = config.type;
    MountDir = config.mountDir;
    StagePublishBaseDir = config.stagePublishBaseDir;
    HealthTimeout = config.healthTimeout;
  };
}
