-- Hyprland Lua Configuration
-- Migrated from hyprland.conf

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "dolphin"

-- Colors from pywal (inline instead of require)
local color0  = "rgb(101012)"
local color1  = "rgb(546065)"
local color2  = "rgb(A45E4C)"
local color3  = "rgb(E59A78)"
local color4  = "rgb(5B7A84)"
local color5  = "rgb(6F8C94)"
local color6  = "rgb(9A9D9E)"
local color7  = "rgb(c2c8c9)"
local color8  = "rgb(878c8c)"
local color9  = "rgb(546065)"
local color10 = "rgb(A45E4C)"
local color11 = "rgb(E59A78)"
local color12 = "rgb(5B7A84)"
local color13 = "rgb(6F8C94)"
local color14 = "rgb(9A9D9E)"
local color15 = "rgb(c2c8c9)"
local background = "rgb(101012)"

-- Monitors (from nwg-displays)
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144.0",
    position = "2560x0",
    scale    = "1",
})

hl.monitor({
    output   = "DP-6",
    mode     = "2560x1440@239.97",
    position = "0x0",
    scale    = "1",
})

-- Autostart
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("awww-daemon --format xrgb --no-cache")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sleep 0.5 && ~/.local/bin/load-last-wallpaper-fast")
    hl.exec_cmd("sleep 1.0 && ~/.local/bin/modern-pywal-sync")
    hl.exec_cmd("~/.local/bin/rust-dock-launcher")
    hl.exec_cmd("~/.local/bin/rust-dock-monitor-watcher")
    hl.exec_cmd("~/.local/bin/wallpaper-monitor-watcher")
end)

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")

-- General
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = color6,
            inactive_border = color8,
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
})

-- Decoration
hl.config({
    decoration = {
        rounding = 10,
        active_opacity = 0.85,
        inactive_opacity = 0.85,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = background,
        },
        blur = {
            enabled = true,
            size = 15,
            passes = 3,
            vibrancy = 0.5,
        },
    },
})

-- Animations
hl.config({ animations = { enabled = true } })

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- Dwindle
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- Master
hl.config({
    master = {
        new_status = "master",
    },
})

-- Misc
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 1,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = true,
        swallow_regex = "^(kitty)$",
        focus_on_activate = true,
        layers_hog_keyboard_focus = false,
    },
})

-- Debug
hl.config({
    debug = {
        vfr = true,
    },
})

-- Input
hl.config({
    input = {
        kb_layout = "us,es",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:win_space_toggle",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Device
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

-- Gestures
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- Window rules
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.layer_rule({
    name  = "rofi-blur",
    match = { namespace = "rofi" },
    blur = true,
})

-- Plugins config is in hyprland.conf (hyprbars) and hyprexpo defaults are fine

---------------------
---- KEYBINDINGS ----
---------------------

-- General
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("~/.local/bin/rust-dock-toggle-all"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("exit"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.local/bin/rofi-style3-monitor-adaptive"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.local/bin/adaptive-rofi run"))
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "overview" }))
hl.bind(mainMod .. " + ALT + Tab", hl.dsp.exec_cmd("~/.local/bin/adaptive-rofi window"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind("ALT + Return", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_performance.sh"))
hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd("~/.local/bin/powermenu-with-monitor-detection"))
hl.bind(mainMod .. " + XF86Back", hl.dsp.exec_cmd("~/.local/bin/pywal-wallpaper-sync"))
hl.bind(mainMod .. " + Prior", hl.dsp.exec_cmd("~/.local/bin/pywal-wallpaper-sync"))
hl.bind(mainMod .. " + SHIFT + BackSpace", hl.dsp.exec_cmd("~/.local/bin/powermenu-with-monitor-detection"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-selector"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("~/.local/bin/wallpaper-change-adaptive"))
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-changer-with-waybar-sync"))

-- Focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Screenshot
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))

-- Special workspace
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume and brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.local/bin/volume-dynamic up"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.local/bin/volume-dynamic down"),  { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.local/bin/volume-dynamic mute"),  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.local/bin/brightness-dynamic up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/brightness-dynamic down"), { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Misc
hl.bind("F10", hl.dsp.exec_cmd("~/.local/bin/toggle-bluetooth"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("~/.local/bin/toggle-keyboard-layout"))
hl.bind("F11", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("F12", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/keyboard-backlight down"))
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("~/.local/bin/keyboard-backlight up"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("~/.config/hypr/scripts/power_save.sh"))
