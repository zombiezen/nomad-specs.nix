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
    cpu = mkOption {
      description = "CPU required to run this task in MHz.";
      default = 100;
      type = types.ints.positive;
    };

    # source: https://github.com/hashicorp/nomad/blob/f45244154288eec153eb4fd5969b66f94e62308e/drivers/docker/driver.go#L768
    memory = mkOption {
      description = "Memory required to run this task in MiB.";
      default = 300;
      type = types.ints.positive;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/resources.go#L9-L23
  config.__toJSON = {
    CPU = config.cpu;
    MemoryMB = config.memory;
  };
}
