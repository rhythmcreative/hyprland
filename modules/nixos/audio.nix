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

    # Microphone denoising through the rnnoise LADSPA plugin.
    #
    # Apagado por defecto (rhythm.audio.denoising) para igualar Arch, donde el
    # filtro solo existe si se pide con toggle-noise-suppression. Encendido sin
    # pedirlo, el microfono salia activo de serie.
    services.pipewire.extraConfig = lib.mkIf cfg.audio.denoising {
      pipewire."99-input-denoising" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          # `nofail` y `node.passive` no son cosmetics, y el propio repo los
          # tiene en la version inline de .local/bin/toggle-noise-suppression
          # (lineas 77 y 97). Esta declaracion se los saltaba, con dos
          # efectos:
          #
          # Sin `nofail`, si el plugin LADSPA no aparece, el nodo falla y
          # arranca con un error por sesion.
          #
          # Sin `node.passive = true`, PipeWire trata el nodo como conectado en
          # activo en vez de como algo a lo que solo se recurre bajo demanda, y
          # el microfono queda permanentemente capturando aunque no haya
          # ninguna app grabando. Eso es lo que hacia que en NixOS el
          # microfono saliera activo de serie y en Arch no: Arch solo carga
          # este filtro cuando se pide con toggle-noise-suppression, y la
          # version que genera ese script si lleva el passive.
          flags = [ "nofail" ];
          args = {
            "node.description" = "Noise-cancelled microphone";
            "media.name" = "Noise-cancelled microphone";
            "capture.props.node.passive" = true;
            "playback.props.node.passive" = true;
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
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      # El plugin se instala siempre: lo necesita tambien
      # toggle-noise-suppression, que lo carga bajo demanda. Lo que se apaga
      # por defecto es el filtro declarativo, no el plugin.
      rnnoise-plugin
    ];
  };
}
