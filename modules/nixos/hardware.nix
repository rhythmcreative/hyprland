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
      # Hardware acceleration support
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = lib.mkMerge [
          (lib.mkIf (cfg.gpu == "intel") (with pkgs; [
            intel-media-driver
            intel-vaapi-driver
            vulkan-intel
          ]))
          (lib.mkIf (cfg.gpu == "amd") (with pkgs; [
            rocmPackages.clr
            rocmPackages.clr.icd
          ]))
        ];
      };
      hardware.enableRedistributableFirmware = true;

      # ASUS ROG/TUF hardware integration
      services.asusd = lib.mkIf cfg.features.asus {
        enable = true;
      };
      environment.systemPackages = lib.mkMerge [
        (lib.mkIf cfg.features.asus [ pkgs.asusctl ])
        (lib.mkIf cfg.features.surface [ pkgs.surface-control ])
      ];
    }

    (lib.mkIf (cfg.gpu == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = lib.mkDefault true;
        powerManagement.enable = lib.mkDefault true;
        open = lib.mkDefault true;
        package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.latest;
      };
    })
  ]);
}
