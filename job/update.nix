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
    stagger = mkOption {
      description = ''
        Delay between each set of `maxParallel` updates when updating system jobs.
        This setting doesn't apply to service jobs which use deployments instead,
        with the equivalent parameter being `minHealthyTime`.
      '';
      default = "30s";
      type = nomadTypes.duration;
    };

    maxParallel = mkOption {
      description = ''
        Number of allocations within a task group that can be updated at the same time.
      '';
      default = 1;
      type = types.ints.unsigned;
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
        - `manual` - Specifies that Nomad should not automatically determine health
          and that the operator will specify allocation health using the HTTP API.
      '';
      default = "checks";
      type = types.enum [ "checks" "task_states" "manual" ];
    };

    minHealthyTime = mkOption {
      description = ''
        Minimum time the allocation must be in the healthy state
        before it is marked as healthy
        and unblocks further allocations from being updated.
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

    progressDeadline = mkOption {
      description = ''
        Deadline in which an allocation must be marked as healthy.
        The deadline begins when the first allocation for the deployment is created
        and is reset whenever an allocation as part of the deployment transitions to a healthy state
        or when a deployment is manually promoted.
        If no allocation transitions to the healthy state before the progress deadline,
        the deployment is marked as failed.
        If the `progressDeadline` is set to 0,
        the first allocation to be marked as unhealthy causes the deployment to fail.
      '';
      default = "10m";
      type = nomadTypes.duration;
    };

    canary = mkOption {
      description = ''
        Specifies that changes to the job that would result in destructive updates
        should create the specified number of canaries without stopping any previous allocations.
        Once the operator determines the canaries are healthy,
        they can be promoted which unblocks a rolling update of the remaining allocations
        at a rate of `maxParallel`.
        Canary deployments cannot be used with volumes when `perAlloc = true`.
      '';
      default = 0;
      type = types.ints.unsigned;
    };

    autoRevert = mkOption {
      description = ''
        If `true`, the job should auto-revert to the last stable job on deployment failure.
        A job is marked as stable if all the allocations as part of its deployment were marked healthy.
      '';
      default = false;
      type = types.bool;
    };

    autoPromote = mkOption {
      description = ''
        If `true`, the job should auto-promote to the canary version
        when all canaries become healthy during a deployment.
        Defaults to `false` which means canaries must be manually updated
        with the `nomad deployment promote` command.
        If a job has multiple task groups, all must be set to `autoPromote = true`
        in order for the deployment to be promoted automatically.
      '';
      default = false;
      type = types.bool;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/2d4611a00cd22ccd0590c14d0a39c051e5764f59/api/jobs.go#L521-L532
  config.__toJSON = {
    Stagger = config.stagger;
    MaxParallel = config.maxParallel;
    HealthCheck = config.healthCheck;
    MinHealthyTime = config.minHealthyTime;
    HealthyDeadline = config.healthyDeadline;
    ProgressDeadline = config.progressDeadline;
    Canary = config.canary;
    AutoRevert = config.autoRevert;
    AutoPromote = config.autoPromote;
  };
}
