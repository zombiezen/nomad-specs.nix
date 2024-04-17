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
    maxParallel = mkOption {
      # TODO(someday): Assert less than the total count for the group
      # as `count - maxParallel` will be left running during migrations.
      description = ''
        Number of allocations that can be migrated at the same time.
      '';
      default = 1;
      type = types.ints.positive;
    };

    healthCheck = mkOption {
      description = ''
        Mechanism in which allocations' health is determined.

        - `checks` - Specifies that the allocation should be considered healthy
          when all of its tasks are running and their associated checks are healthy,
          and unhealthy if any of the tasks fail or not all checks become healthy.
          This is a superset of `task_states` mode.
        - `task_states` - Specifies that the allocation should be considered healthy
          when all its tasks are running and unhealthy if tasks fail.
      '';
      default = "checks";
      type = types.enum [ "checks" "task_states" ];
    };

    minHealthyTime = mkOption {
      description = ''
        Minimum time the allocation must be in the healthy state
        before it is marked as healthy
        and unblocks further allocations from being migrated.
      '';
      default = "10s";
      type = nomadTypes.duration;
    };

    healthyDeadline = mkOption {
      description = ''
        Deadline in which the allocation must be marked as healthy
        after which the allocation is automatically transitioned to unhealthy.
      '';
      default = "5m";
      type = nomadTypes.duration;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/tasks.go#L335-L342
  config.__toJSON = {
    MaxParallel = config.maxParallel;
    HealthCheck = config.healthCheck;
    MinHealthyTime = config.minHealthyTime;
    HealthyDeadline = config.healthyDeadline;
  };
}
