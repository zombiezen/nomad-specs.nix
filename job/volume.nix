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

# This isn't a module, just a function that returns a type.
{ lib }:

let
  inherit (lib) types;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.options) mkOption;

  inherit (import ../internal.nix { inherit lib; }) attrTagOption;

  common = { config, ... }: {
    options.readOnly = mkOption {
      description = ''
        Specifies that the group only requires read only access to a volume
        and is used as the default value for the `volumeMount.readOnly` configuration.
        This value is also used for validating `hostVolume` ACLs
        and for scheduling when a matching `hostVolume` requires `readOnly` usage.
      '';
      default = false;
      type = types.bool;
    };

    options.perAlloc = mkOption {
      description = ''
        If `true`, the source of the volume should have the suffix `[n]`,
        where `n` is the allocation index.
        This allows mounting a unique volume per allocation,
        so long as the volume's source is named appropriately.

        For example, with the source `myvolume` and `perAlloc = true`,
        the allocation named `myjob.mygroup.mytask[0]`
        will require a volume ID `myvolume[0]`.
      '';
      default = false;
      type = types.bool;
    };

    options.__toJSON = mkOption {
      internal = true;
      visible = false;
      readOnly = true;
    };
  };

  commonToJSON = name: config: {
    Name = name;
    Source = config.source;
    ReadOnly = config.readOnly;
    PerAlloc = config.perAlloc;
  };
in

types.attrTag {
  host = mkOption {
    description = ''
      Host volume.
    '';
    type = types.submodule ({ config, ... }: {
      imports = [ common ];

      options.source = mkOption {
        description = ''
          Name of the host volume to request.
        '';
        type = types.str;
      };

      # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/tasks.go#L404-L414
      config.__toJSON = name: (commonToJSON name config) // {
        Type = "host";
      };
    });
  };

  csi = mkOption {
    description = ''
      CSI plugin.
    '';
    type = types.submodule ({ config, ...}: {
      imports = [ common ];

      options.source = mkOption {
        description = ''
          Name of the CSI volume ID to request.
        '';
        type = types.str;
      };

      options.accessMode = mkOption {
        description = ''
          Defines whether a volume should be available concurrently.
        '';
        type = types.enum [
          "single-node-reader-only"
          "single-node-writer"
          "multi-node-reader-only"
          "multi-node-single-writer"
          "multi-node-multi-writer"
        ];
      };

      options.attachment = mkOption {
        description = ''
          Storage API that will be used by the volume.
        '';
        type = types.attrTag {
          block-device = mkOption {
            description = "Use the block device API.";
            type = types.enum [ true ];
          };

          file-system = mkOption {
            description = "Use the filesystem API.";
            type = types.submodule {
              options.fsType = mkOption {
                description = "File system type";
                example = "ext4";
                default = "";
                type = types.str;
              };

              options.mountFlags = mkOption {
                description = "Flags passed to `mount`";
                default = [];
                type = types.listOf types.str;
              };
            };
          };
        };
      };

      # https://github.com/hashicorp/nomad/blob/0f34c85ee63f6472bd2db1e2487611f4b176c70c/api/tasks.go#L404-L414
      config.__toJSON = name: (commonToJSON name config) // {
        Type = "csi";
        AccessMode = config.accessMode;
        AttachmentMode = attrTagOption config.attachment;
      } // optionalAttrs (config.attachment ? file-system) (
        let c = config.attachment.file-system; in {
          MountOptions = {
            FSType = c.fsType;
            MountFlags = c.mountFlags;
          };
        }
      );
    });
  };
}
