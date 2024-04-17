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
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
in

{
  options = {
    enabled = mkOption {
      description = ''
        Whether the job should run.
        Setting to `false` not only prevents this job from running on the `cron` schedule
        but prevents force launches.
      '';
      default = true;
      type = types.bool;
    };

    cron = mkOption {
      description = ''
        Cron expressions configuring the interval to launch the job.
        In addition to cron-specific formats,
        this option also includes predefined expressions such as `@daily` or `@weekly`.
      '';
      type = types.coercedTo types.str singleton (types.listOf types.str);
    };

    prohibitOverlap = mkOption {
      description = ''
        If `true`, this job should wait until previous instances of this job have completed.
        This only applies to this job;
        it does not prevent other periodic jobs from running at the same time.
      '';
      default = false;
      type = types.bool;
    };

    timeZone = mkOption {
      description = ''
        Time zone to evaluate the next launch interval against.
        Daylight Saving Time affects scheduling in some timezones,
        so be careful.
        The time zone must be parsable by Go's `time.LoadLocation`.
      '';
      default = "UTC";
      type = types.str;
    };

    __toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/jobs.go#L825-L832
  config.__toJSON = {
    Enabled = config.enabled;
    Specs = config.cron;
    ProhibitOverlap = config.prohibitOverlap;
    TimeZone = config.timeZone;
  };
}
