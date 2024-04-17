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

{ self, lib, runCommandLocal, testers }:

let
  mkJob = { ID, ... }@args: { Job = {
    Region = "global";
    Namespace = "default";
    Name = ID;
    Datacenters = ["*"];
    Type = "service";
    Priority = 50;
    Constraints = [];
    TaskGroups = [];
  } // args; };

  evalTests = {
    testDefaultJob = {
      expr = self.lib.evalJobspec { modules = [
        {
          id = "foo";
        }
      ]; };
      expected = mkJob {
        ID = "foo";
      };
    };
  };

  failureToString = { name, expected, result }: ''
    ${name} failed!
    want:
    ${builtins.toJSON expected}

    got:
    ${builtins.toJSON result}
  '';
in

{
  checks.evalJobspec = runCommandLocal "nomad-jobspec-tests" {
    failures = lib.strings.concatStringsSep "\n\n" (builtins.map failureToString (lib.debug.runTests evalTests));
    passAsFile = ["failures"];
  } ''
    if [[ -s "$failuresPath" ]]; then
      cat "$failuresPath" >&2
      exit 1
    else
      touch "$out"
      exit 0
    fi
  '';
}
