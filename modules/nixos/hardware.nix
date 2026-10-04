# Hardware scope: GPU stack and vendor quirks.
#
# install.sh probes with lspci at install time and writes modprobe rules,
# mkinitcpio MODULES and a pacman hook. NixOS owns the boot builder, so the
# equivalent is explicit options here. Set rhythm.gpu when the hardware is
# known; "auto" keeps modesetting defaults plus NVIDIA when present.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      hardware.graphics.enable = true;
      hardware.enableRedistributableFirmware = true;

      # Vendor tools (asusctl, surface kernels) are intentionally not
      # installed by default: NixOS cannot probe PCI IDs at build time the
      # way install.sh does with lspci. Add them in the host config when
      # the hardware is known (see hosts/example).
    }

    (lib.mkIf (cfg.gpu == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        open = true;
        package = config.boot.kernelPackages.nvidiaPackages.latest;
      };
    })

    (lib.mkIf (cfg.gpu == "amd") {
      # OpenCL through ROCm; the exact package set follows the nixpkgs
      # hardware.graphics convention (extraPackages, no amdgpu-specific
      # option exists for this).
      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
      ];
    })
  ]);
}
