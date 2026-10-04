# Audio scope: PipeWire plus microphone denoising.
#
# On Arch the installer enables pipewire user sockets by hand and offers
# noise-suppression-for-voice (an AUR package with no nixpkgs equivalent).
# Here PipeWire is declarative, and denoising is an rnnoise LADSPA
# filter-chain on the microphone source (see ADR-0002). EasyEffects stays
# available as an app for anyone wanting a GUI instead.
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
in
{
  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Microphone denoising through the rnnoise LADSPA plugin, always on.
    services.pipewire.extraConfig.pipewire."99-input-denoising" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Noise-cancelled microphone";
            "media.name" = "Noise-cancelled microphone";
            "filter.graph" = {
              nodes = [
                {
                  type = "ladspa";
                  name = "rnnoise";
                  plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                  label = "noise_suppressor_mono";
                  control = {
                    "VAD Threshold" = 50.0;
                  };
                }
              ];
            };
            "audio.rate" = 48000;
            "audio.channels" = 1;
            "audio.position" = [ "MONO" ];
          };
        }
      ];
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      rnnoise-plugin
    ];
  };
}
