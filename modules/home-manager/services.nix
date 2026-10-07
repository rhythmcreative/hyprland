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
  # The scripts these units run are `while true` pollers: they call `sleep`
  # between iterations and `date`/`ls`/`grep` to look at the world. A `sleep`
  # that is not on PATH does not fail the loop, it removes the only thing
  # slowing it down, so the unit spins at full speed and forks until the load
  # average goes through the roof and the journal fills with `command not
  # found` (measured: 1,067,228 of them in five minutes, load 12.37 on 8
  # cores, 756MB of journal).
  #
  # `Environment=PATH=` REPLACES the session PATH, it does not extend it, so
  # nothing here can be picked up from ~/.nix-profile or the system profile
  # either. Every tool the scripts call by bare name has to be listed.
  #
  # coreutils/gnugrep/gawk/gnused are the four that were missing outright and
  # cost the most: sleep, date, ls, head, cat, basename, tr, mkdir, rm, id,
  # cut, wc, readlink, grep, awk and sed. procps was already here (pgrep,
  # pkill, ps) but is referenced below as well, because the services that call
  # it need it more than the ones that do not.
  #
  # Same reasoning, and the same treatment, as the greeter wrapper in
  # packages/greeter-monitor, which already ships coreutils/procps/gawk/gnugrep/
  # gnused for exactly this reason.
  hyprTools = with pkgs; [
    coreutils
    findutils
    gnugrep
    gawk
    gnused
    hyprland
    jq
    procps
    systemd
    socat
    util-linux
    # bash: not just for shebangs. These scripts shell out with `bash -c` and
    # resolve it through PATH, and several of the island helpers are launched
    # from a unit that inherits this PATH.
    bash
    # python3: hypr-event-stream is a python script the rust-dock watcher
    # restarts every 2s to read Hyprland's event socket. Without it on PATH
    # it died on spawn, so monitoradded/monitorremoved never arrived and
    # neither Waybar nor the dock was reconciled on hotplug. The island
    # sensors shell out to `python3 -c` inline for the same reason.
    python3
    # waybar: rust-dock-monitor-watcher's reconcile_waybar runs launch.sh,
    # which execs `waybar`. Without it here the reconcile fired every 90s,
    # the launcher logged "waybar: command not found" and the bar was never
    # restarted after dying. This was the whole reason the bar "came and
    # went".
    waybar
    # pactl: volume-dynamic (bound to the volume keys) calls it. The session
    # runs PipeWire, which does not ship a `pactl`, so the F11/F12 and mute
    # keys did nothing at all until pulseaudio is on PATH.
    pulseaudio
    # SUID wrappers live in /run/wrappers/bin, which no unit PATH included, so
    # battery-charge-limit could not reach sudo or pkexec and the charge limit
    # could not be set from the island.
    sudo
    polkit
  ];

  # The watchers additionally call these by bare name. The scripts guard some
  # of them with `command -v` and degrade silently when they are missing, so
  # they never showed up as an error: privacy-shield just stopped being able
  # to tell whether the camera light was on.
  notifyTools = with pkgs; [ libnotify psmisc lsof wireplumber ];

  # The dynamic island runs every sensor as `Quickshell.execDetached(["bash",
  # "-c", ...])`, roughly 31 of them, so it needs an interpreter on PATH
  # before it needs anything else. Without `bash` here Quickshell resolved
  # argv[0] through PATH, failed to find it, and every one of those processes
  # died at spawn: the island still drew its layer, but volume, brightness,
  # wifi, clipboard, battery, privacy and dock state all stayed blank, and
  # logged 3675 "binary could not be found" warnings in ten minutes.
  #
  # The rest are the tools those 31 commands pipe through. wireplumber brings
  # wpctl, brightnessctl reads the backlight and nmcli reports the network;
  # all three are already desktop packages, so they only had to be named on
  # the unit PATH.
  islandTools = with pkgs; [
    # pkgs.bash a proposito, no el bash-interactive que trae hyprTools por
    # otra via: Quickshell resuelve argv[0] ("bash") a traves del PATH, y el
    # paquete interactivo expone el binario como `bash` dentro de su propio
    # prefix pero no como `bash` en un directorio que el proceso entidad
    # llegue a usar. Con el paquete normal el symlink queda en <pkg>/bin/bash,
    # que es justo lo que el QML pide 31 veces.
    bash
    quickshell
    waybar
    wireplumber
    brightnessctl
    networkmanager
    playerctl
    cliphist
    hyprpicker
    wf-recorder
    slurp
    grim
    wl-clipboard
    libnotify
  ];
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
            # Same reasoning as waybar-island below: default.target comes
            # before the compositor, so the daemon waits for the Wayland
            # socket instead of exiting. A start-limit-hit here degrades the
            # whole user session, which home-manager reports on every
            # activation, so restarts stay unlimited.
            StartLimitIntervalSec = 0;
          };
          Service = {
            # cliphist-daemon polls in a `while true` with `sleep 1`, and
            # dedupes with `pgrep` before storing an entry, so it needs
            # coreutils and procps. It had neither: the loop ran flat out and
            # the pgrep guard never matched, so every wl-paste event was
            # stored without being compared against the last one.
            Environment = [ "PATH=${lib.makeBinPath (with pkgs; [ cliphist wl-clipboard coreutils procps ])}" ];
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
            Environment = [ "PATH=/run/wrappers/bin:/run/current-system/sw/bin:${lib.makeBinPath (hyprTools)}" ];
            Type = "oneshot";
            # Source rhythm-battery-limit.service: battery-charge-limit --apply.
            ExecStart = "${bin}/battery-charge-limit --apply";
            RemainAfterExit = false;
          };
          Install.WantedBy = [ "default.target" ];
        };

        polkit-kde-authentication-agent-1 = {
          Unit = {
            Description = "Polkit KDE Authentication Agent";
            After = [ "graphical-session.target" "default.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = "1s";
            TimeoutStopSec = "10s";
          };
          Install.WantedBy = [ "graphical-session.target" "default.target" ];
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
            Environment = [ "PATH=/run/wrappers/bin:/run/current-system/sw/bin:${lib.makeBinPath (hyprTools ++ islandTools)}" ];
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
            # privacy-shield-daemon polls every POLL_INTERVAL and was the
            # single hungriest process in the session at 45% CPU, because
            # its `sleep` was missing. It also calls notify-send, fuser and
            # lsof behind `command -v` guards to decide whether the camera
            # and mic are live, so without them it could not see them and had
            # nothing to warn about.
            Environment = [ "PATH=${lib.makeBinPath (hyprTools ++ notifyTools)}" ];
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
