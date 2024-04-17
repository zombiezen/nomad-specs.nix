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
    attempts = mkOption {
      description = ''
        Number of restarts allowed in the configured interval.
        Defaults vary by job type.
      '';
      type = types.nullOr types.ints.unsigned;
      example = 2;
    };

    interval = mkOption {
      description = ''
        Duration which begins when the first task starts
        and ensures that only `attempts` number of restarts happens within it.
        If more than `attempts` number of failures happen,
        behavior is controlled by `mode`.
        Defaults vary by job type.
      '';
      type = types.nullOr nomadTypes.duration;
      example = "30m";
    };

    delay = mkOption {
      description = ''
        Duration to wait before restarting a task.
        A random jitter of up to 25% is added to the delay.
      '';
      default = "15s";
      type = nomadTypes.duration;
    };

    mode = mkOption {
      description = ''
        Behavior when the task fails more than `attempts` times in `interval`.

        - `delay` - Instructs the client to wait until another `interval`
          before restarting the task.
        - `fail` - Instructs the client not to attempt to restart the task
          once the number of attempts have been used.
          This is the default behavior.
          This mode is useful for non-idempotent jobs
          which are unlikely to succeed after a few failures.
          The allocation will be marked as failed
          and the scheduler will attempt to reschedule the allocation
          according to the `reschedule` block.
      '';
      default = "fail";
      type = types.enum [ "fail" "delay" ];
    };

    renderTemplates = mkOption {
      description = ''
        If set to `true`, all templates will be re-rendered when the task restarts.
        This can be useful for re-fetching Vault secrets,
        even if the lease on the existing secrets has not yet expired.
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

  # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/tasks.go#L90-L96
  config.__toJSON = {
    Interval = config.interval;
    Attempts = config.attempts;
    Delay = config.delay;
    Mode = config.mode;
    RenderTemplates = config.renderTemplates;
  };
}
