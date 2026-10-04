# User units, translated from .config/systemd/user.
#
# Each entry cites the source unit so the translation stays reviewable.
# Two rules applied throughout:
# - No FHS-absolute binaries (/usr/bin/...): everything is a store path,
#   either the helpers package or an explicit pkgs dependency.
# - Helpers call bare tools (hyprctl, jq, quickshell, awww...), so every
#   service carries a `path` with what its scripts need at runtime.
#
# WantedBy mirrors enable-user-services: default.target for services,
# timers.target for timers, except rhythm-caffeine and rhythm-hyprsunset,
# which start on demand (enabling them would force the inhibitor and the
# night light on from every login).
{ config, lib, pkgs, ... }:

let
  cfg = config.rhythm;
  helpers = cfg.packageSet.helpers;
  bin = "${helpers}/bin";
  hyprTools = with pkgs; [ hyprland jq procps systemd socat ];
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      systemd.user.services = {
        cliphist = {
          Unit = {
            Description = "Clipboard history watcher (cliphist over wl-paste)";
            # Source cliphist.service: After=default.target.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (with pkgs; [ cliphist wl-clipboard ])}" ];
            Type = "simple";
            # Source cliphist.service: ExecStart=%h/.local/bin/cliphist-daemon.
            ExecStart = "${bin}/cliphist-daemon";
            Restart = "always";
            RestartSec = "2s";
          };
          Install.WantedBy = [ "default.target" ];
        };

        rhythm-battery-limit = {
          Unit = {
            Description = "Re-apply the battery charge limit";
            # Source rhythm-battery-limit.service: reapplies
            # charge_control_end_threshold, which the kernel does not persist.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools)}" ];
            Type = "oneshot";
            # Source rhythm-battery-limit.service: battery-charge-limit --apply.
            ExecStart = "${bin}/battery-charge-limit --apply";
            RemainAfterExit = false;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    }

    (lib.mkIf cfg.features.island {
      systemd.user.services = {
        waybar-island = {
          Unit = {
            Description = "Dynamic Island and Notification Server for Hyprland/Waybar";
            # Source waybar-island.service: WantedBy deliberately targets
            # default.target, never graphical-session.target, which stays
            # inactive in a Hyprland session started via SDDM.
            After = [ "default.target" ];
            # The launcher waits for the Wayland socket, which used to trip
            # the start limit; unlimited restarts beat losing the island.
            StartLimitIntervalSec = 0;
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ (with pkgs; [ quickshell waybar ]))}" ];
            Type = "simple";
            # Source waybar-island.service: ExecStart=%h/.local/bin/quickshell-island.
            ExecStart = "${bin}/quickshell-island";
            Restart = "always";
            RestartSec = "2s";
          };
          Install.WantedBy = [ "default.target" ];
          # The launcher ends in `exec quickshell -p ...` and probes the
          # compositor with hyprctl while waiting for the socket.
        };

        island-watchdog = {
          Unit = {
            Description = "Restart the island if quickshell is alive but has no layer";
            # Source island-watchdog.service: covers the gap systemd cannot,
            # a live process with no compositor layer, acting only after two
            # consecutive layer-less checks.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools)}" ];
            Type = "oneshot";
            # Source island-watchdog.service: ExecStart=%h/.local/bin/island-watchdog.
            ExecStart = "${bin}/island-watchdog";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      systemd.user.timers = {
        island-watchdog = {
          Unit = {
            Description = "Check every minute that the island is still on screen";
          };
          Timer = {
            # Source island-watchdog.timer: OnBootSec=90s OnUnitActiveSec=60s
            # AccuracySec=10s, Unit=island-watchdog.service.
            OnBootSec = "90s";
            OnUnitActiveSec = "60s";
            AccuracySec = "10s";
            Unit = "island-watchdog.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.wallpaperWatcher {
      systemd.user.services = {
        wallpaper-monitor-watcher = {
          Unit = {
            Description = "Monitor watcher for Wallpaper auto-synchronization";
            # Source wallpaper-monitor-watcher.service: same SDDM analysis as
            # the island, WantedBy must be default.target.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ (with pkgs; [ awww mpvpaper ]))}" ];
            Type = "simple";
            ExecStart = "${bin}/wallpaper-monitor-watcher";
            Restart = "always";
            RestartSec = "2s";
          };
          Install.WantedBy = [ "default.target" ];
          # The watcher repaints through wallpaper-backend, which shells out
          # to awww and mpvpaper.
        };
      };
    })

    (lib.mkIf cfg.features.rustDock {
      systemd.user.services = {
        rust-dock-monitor-watcher = {
          Unit = {
            Description = "Monitor watcher for Rust-Dock, Waybar and Wallpaper auto-synchronization";
            # Source rust-dock-monitor-watcher.service: After=default.target.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ [ cfg.packageSet.rustDock ])}" ];
            Type = "simple";
            ExecStart = "${bin}/rust-dock-monitor-watcher";
            Restart = "always";
            RestartSec = "2s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.bluetooth {
      systemd.user.services = {
        rhythm-bluetooth-agent = {
          Unit = {
            Description = "BlueZ pairing agent that asks for confirmation in the dynamic island";
            # Source rhythm-bluetooth-agent.service: After orders against
            # graphical-session.target without requiring it, so it is kept.
            After = [ "graphical-session.target" "bluetooth.service" ];
            Wants = [ "bluetooth.service" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ (with pkgs; [ bluez ]))}" ];
            Type = "simple";
            ExecStart = "${bin}/bluetooth-pair-agent serve";
            Restart = "always";
            RestartSec = "3s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.powerProfile {
      systemd.user.services = {
        rhythm-power-profile = {
          Unit = {
            Description = "Rhythm Hyprland Automatic Power Profile Daemon";
            # Source rhythm-power-profile.service: After alone only orders
            # startup, so keeping graphical-session.target here is safe.
            After = [ "graphical-session.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ (with pkgs; [ power-profiles-daemon upower ]))}" ];
            Type = "simple";
            ExecStart = "${bin}/auto-power-profile";
            Restart = "always";
            RestartSec = "5";
            StandardOutput = "journal";
            StandardError = "journal";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.privacyShield {
      systemd.user.services = {
        privacy-shield = {
          Unit = {
            Description = "Camera and microphone privacy shield watchdog";
            # Source privacy-shield.service: After=default.target.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools)}" ];
            Type = "simple";
            ExecStart = "${bin}/privacy-shield-daemon";
            Restart = "always";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.nightlight {
      systemd.user.services = {
        rhythm-hyprsunset = {
          Unit = {
            Description = "Night Light gamma ramp (hyprsunset)";
            # Source rhythm-hyprsunset.service: no After/PartOf against
            # graphical-session.target on purpose; the schedule timer below
            # recovers the ramp within about 40s.
            StartLimitIntervalSec = 0;
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ (with pkgs; [ hyprsunset ]))}" ];
            Type = "exec";
            ExecStart = "${bin}/hyprsunset-daemon";
            Restart = "on-failure";
            RestartSec = "3";
            TimeoutStopSec = "5";
          };
          # No Install section: started on demand by toggle-nightlight and
          # the schedule timer, mirroring the enable-user-services exclusion.
        };

        rhythm-nightlight-schedule = {
          Unit = {
            Description = "Rhythm Night Light scheduled on/off check";
            # Source rhythm-nightlight-schedule.service: no ordering against
            # graphical-session.target; the timer re-drives every 60s.
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools)}" ];
            Type = "oneshot";
            ExecStart = "${bin}/night-light-schedule";
            TimeoutStartSec = "20";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      systemd.user.timers = {
        rhythm-nightlight-schedule = {
          Unit = {
            Description = "Check the Rhythm Night Light schedule every minute";
          };
          Timer = {
            # Source rhythm-nightlight-schedule.timer: OnBootSec=45s
            # OnUnitActiveSec=60s AccuracySec=10s Persistent=false.
            OnBootSec = "45s";
            OnUnitActiveSec = "60s";
            AccuracySec = "10s";
            Persistent = false;
            Unit = "rhythm-nightlight-schedule.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.otaCheck {
      systemd.user.services = {
        rhythm-ota-check = {
          Unit = {
            Description = "Rhythm Hyprland Background OTA Update Check";
            # Source rhythm-ota-check.service: After/Wants network-online.target.
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools)}" ];
            Type = "oneshot";
            ExecStart = "${bin}/rhythm-ota-checker";
            StandardOutput = "journal";
            StandardError = "journal";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      systemd.user.timers = {
        rhythm-ota-check = {
          Unit = {
            Description = "Timer for Rhythm Hyprland OTA Update Check";
          };
          Timer = {
            # Source rhythm-ota-check.timer: OnBootSec=2min
            # OnUnitActiveSec=8h Persistent=true.
            OnBootSec = "2min";
            OnUnitActiveSec = "8h";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })

    (lib.mkIf cfg.features.caffeine {
      systemd.user.services = {
        rhythm-caffeine = {
          Unit = {
            Description = "Rhythm Caffeine Mode idle and sleep inhibitor";
            # Source rhythm-caffeine.service: After=default.target.
            After = [ "default.target" ];
          };
          Service = {
            Environment = [ "PATH=${lib.makeBinPath (hyprTools)}" ];
            Type = "simple";
            # Source ExecStart wraps caffeine-keeper in systemd-inhibit and
            # ExecStopPost resumes hypridle with pkill -CONT; both binaries
            # were FHS-absolute upstream and are store paths here.
            ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep --mode=block --who=Rhythm-Caffeine --why=Awake-mode-is-enabled ${bin}/caffeine-keeper";
            Restart = "always";
            RestartSec = "2s";
            ExecStopPost = "${pkgs.procps}/bin/pkill -CONT -x hypridle";
          };
          # No Install section: the island toggle starts this while its flag
          # exists, mirroring the enable-user-services exclusion.
        };
      };
    })
  ]);
}
