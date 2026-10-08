-- Hyprland Lua Configuration
-- Migrated from hyprland.conf

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "thunar"

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

-- Monitors
--
-- El orden de estas reglas importa y no es el intuitivo: en esta versión de
-- Hyprland GANA LA ÚLTIMA REGLA QUE COINCIDE, no la primera. Está medido —
-- con la regla del portátil antes que las de nwg-displays, la disposición
-- guardada se aplicaba al revés en cuanto el portátil também estaba nombrado.
--
-- 1) Red de seguridad, primero. Lo que nwg-displays no mencione cae aquí.
-- 2) Lo que nwg-displays guardó, después, y por tanto manda.
--
-- El primero de los dos no lleva posición a propósito. Con eDP-1 anclado en
-- 2560x0 y DP-6 en 0x0 —como estaban escritos— el escritorio se rompía al
-- cambiar la topología: al desenchufar DP-6, el portátil se quedaba en un x
-- que ya no existía y quedaba un hueco de 2560px a su izquierda. Sin
-- posición, Hyprland la coloca sola y el hueco no puede aparecer. Lo único que
-- se le fija es la escala, porque su valor por defecto es 1.5 en una 1080p y
-- deja el texto diminuto.
--
-- Para un monitor sin ninguna regla, Hyprland aplica modo preferido, posición
-- automática y escala automática: al enchufar uno nuevo se coloca solo.
--
-- OJO: en esta versión los comodines en `output` no coinciden (`eDP-*` no hace
-- nada), así que el panel interno va por su nombre exacto. Por lo mismo
-- `output = ""` no actúa de regla general.
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-- Lo que nwg-displays guarda en monitors.conf, aplicado de verdad.
--
-- nwg-displays llevaba tiempo escribiendo ese fichero y nada lo leía: este
-- config no tenía ninguna regla para él, así que guardar una disposición allí
-- no cambiaba nada. Tampoco se puede resolver con `require`, que solo carga
-- Lua, y esto son líneas `monitor=`.
--
-- Se parsea aquí, en el momento de cargar, y se convierte en llamadas a
-- hl.monitor. Leerlo con io en vez de con require es a propósito: nwg-displays
-- reescribe el fichero cada vez que guardas, y require cachearía el resultado,
-- así que tras guardar y recargar seguiría viéndose la disposición antigua.
--
-- Un fichero ausente o mal formado no es un error: la config carga igual y se
-- comporta como si nwg-displays no se hubiera usado nunca.
--
-- AVISO, porque es la contrapartida de que esto funcione: aquí se respetan las
-- posiciones TAL CUAL están guardadas, incluidas las de monitores que ahora no
-- están enchufados. Si guardas una disposición con dos pantallas y luego
-- desenchafas una, la otra se queda en el x que ya no existe y queda el hueco
-- — es exactamente lo que pasaba antes, solo que ahora lo decides tú desde la
-- herramienta. Guarda la disposición con los monitores que tienes conectados, o
-- simplemente borra la línea del que no esté. Para la disposición automática
-- (sin huecos, se recoloca sola al enchufar y desenchufar) basta con tener
-- monitors.conf vacío o borrar su contenido.
local function aplicar_monitors_nwg()
    local ruta = (os.getenv("HOME") or "") .. "/.config/hypr/monitors.conf"
    local f = io.open(ruta, "r")
    if not f then return end
    for linea in f:lines() do
        local limpio = linea:gsub("^%s+", ""):gsub("%s+$", "")
        if limpio ~= "" and not limpio:match("^#") then
            local partes = {}
            for p in limpio:gmatch("[^,]+") do partes[#partes + 1] = p end
            -- monitor=SALIDA,MODO,POSICION,ESCALA[,TRANSFORM][,vrr][,PROFUNDIDAD]
            local salida = partes[1] and partes[1]:match("^monitor%s*=%s*(.+)$")
            local modo, pos, escala = partes[2], partes[3], partes[4]
            if salida and salida ~= "" and modo and pos and escala then
                local regla = {
                    output   = salida,
                    mode     = modo,
                    position = pos,
                    scale    = escala,
                }
                -- Lo que sigue a la escala es la transformacion (0-3) o la
                -- palabra "vrr". Se pasa lo que se entienda, se ignora lo demás.
                local extra = partes[5]
                if extra then
                    if extra:match("^%d+$") and tonumber(extra) <= 3 then
                        regla.transform = tonumber(extra)
                    elseif extra:lower() == "vrr" then
                        regla.vrr = 1
                    end
                end
                hl.monitor(regla)
            end
        end
    end
    f:close()
end

aplicar_monitors_nwg()

-- Autostart
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("~/.local/bin/load-last-wallpaper-fast &")
    hl.exec_cmd("command -v pipewire >/dev/null 2>&1 && ! pidof -s pipewire >/dev/null 2>&1 && pipewire &")
    hl.exec_cmd("command -v wireplumber >/dev/null 2>&1 && ! pidof -s wireplumber >/dev/null 2>&1 && wireplumber &")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets &")
    hl.exec_cmd("nm-applet --indicator &")
    hl.exec_cmd("hypridle &")
    hl.exec_cmd("~/.config/waybar/launch.sh &")
    hl.exec_cmd("~/.local/bin/rust-dock-launcher &")
    hl.exec_cmd("~/.local/bin/quickshell-island &")
    hl.exec_cmd("sleep 0.8 && ~/.local/bin/modern-pywal-sync --startup")
    -- Pinned compositor plugins on NixOS. The flake exports one env var per
    -- plugin with the store path of its .so; hyprctl loads them here. Unset
    -- on Arch (hyprpm owns plugin loading there), so this stays a no-op.
    for _, var in ipairs({ "RHYTHM_PLUGIN_HYPRBARS", "RHYTHM_PLUGIN_HYPREXPO" }) do
        local so = os.getenv(var)
        if so and so ~= "" then
            hl.exec_cmd("hyprctl plugin load " .. so)
        end
    end
end)

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
-- Motores de Qt. En Arch son qt5ct y kvantum, y estan instalados.
-- En NixOS ninguno de los dos existe en nixpkgs, y el modulo del escritorio
-- deja QT_QPA_PLATFORMTHEME=qt6ct y QT_STYLE_OVERRIDE=adwaita en el entorno
-- de la sesion (adwaita-qt6 es el puente GTK->Qt que hay disponible).
--
-- Por eso solo se fijan si NO vienen ya de fuera: en Arch, donde no llegan,
-- se mantienen estos; en NixOS, donde llegan, hyprctl no pisa el valor.
if not os.getenv("QT_QPA_PLATFORMTHEME") then
    hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
end
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
if not os.getenv("QT_STYLE_OVERRIDE") then
    hl.env("QT_STYLE_OVERRIDE", "kvantum")
end
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
hl.animation({ leaf = "layers",        enabled = true, speed = 4,    bezier = "quick" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "quick" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3.5,  bezier = "quick" })
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
        background_color = "0x111319",
        disable_hyprland_guiutils_check = true,
        disable_watchdog_warning = true,
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
        kb_options = "",
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

hl.layer_rule({
    name  = "waybar-slide",
    match = { namespace = "waybar" },
    animation = "slide top",
})

hl.layer_rule({
    name  = "rust-dock-slide",
    match = { namespace = "rust-dock" },
    animation = "slide bottom",
})
-- La isla es la capa `quickshell` (su proceso se llama asi aunque el binario sea
-- quickshell-island), y se escondia y se revelaba DESTRUYENDO la capa, sin
-- animacion: waybar entra deslizando y la Isla aparecia de golpe. Con esta regla
-- entra por arriba, como la barra, que es lo que hacia falta para que se leyeran
-- como una sola cosa.
--
-- La capa de la isla ocupa la pantalla entera en los dos monitores, no solo la
-- franja de arriba: el animarse la mueve entera. Es lo que se quiere, porque el
-- resto va en alfa 0 y solo se ve la Isla.
hl.layer_rule({
    name  = "island-slide",
    match = { namespace = "quickshell" },
    animation = "slide top",
})

-- Plugins config is in hyprland.conf (hyprbars) and hyprexpo defaults are fine

---------------------
---- KEYBINDINGS ----
---------------------

-- General
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("~/.local/bin/rust-dock-toggle-all"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("~/.local/bin/rust-dock-toggle-all"))
hl.bind("SUPER + space", hl.dsp.exec_cmd("~/.local/bin/rust-dock-toggle-all"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("~/.local/bin/rust-dock-toggle-all"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("~/.local/bin/toggle-island"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("~/.local/bin/show-hotkeys"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/.local/bin/settings-menu"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/.local/bin/rofi-wifi-menu"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.local/bin/rofi-bluetooth-menu"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.local/bin/open-clipboard"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.local/bin/open-notifications"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.local/bin/rofi-style3-monitor-adaptive"))
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "overview" }))
hl.bind(mainMod .. " + ALT + Tab", hl.dsp.exec_cmd("~/.local/bin/adaptive-rofi window"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
-- `hyprctl dispatch <args>` NO funciona en esta build: hyprctl envuelve los
-- argumentos en hl.dispatch(...) y eso no es Lua valido, asi que falla con
-- "')' expected near". El equivalente verificado es hyprctl eval con el
-- dispatcher de la API de lua.
hl.bind("ALT + Return", hl.dsp.exec_cmd("hyprctl eval 'hl.dsp.window.fullscreen(0)'"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_performance.sh"))
hl.bind(mainMod .. " + BackSpace", hl.dsp.exec_cmd("~/.local/bin/powermenu-with-monitor-detection"))
hl.bind(mainMod .. " + XF86Back", hl.dsp.exec_cmd("~/.local/bin/pywal-wallpaper-sync"))
hl.bind(mainMod .. " + Prior", hl.dsp.exec_cmd("~/.local/bin/pywal-wallpaper-sync"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-selector"))
hl.bind(mainMod .. " + CONTROL + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-selector"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("~/.local/bin/wallpaper-change-adaptive"))

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
hl.bind(mainMod .. " + ALT + K", hl.dsp.exec_cmd("~/.local/bin/cast-screen"))
hl.bind("F11", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("F12", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/keyboard-backlight down"))
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("~/.local/bin/keyboard-backlight up"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("~/.config/hypr/scripts/power_save.sh"))

-- Omarchy-style toggle (Do Not Disturb)
hl.bind(mainMod .. " + CONTROL + D", hl.dsp.exec_cmd("~/.local/bin/toggle-dnd"), { locked = true })

-- ── Ediciones del usuario, cargadas AL FINAL ─────────────────────────────────
--
-- Este fichero entero viene del repo y el update lo re-pone. Lo que quieras
-- cambiar sin que te lo pisen va en user.lua, que se carga aqui y por eso gana:
-- todo lo de arriba sigue en pie, y lo tuyo se aplica encima.
--
-- Patrón de Ryoku, que es la razon de que esto sea un fichero y no un `if`: si
-- sustituyes hyprland.lua entero por una copia tuya, dejas de recibir los
-- cambios de arriba. Si solo escribes user.lua, cada bind, regla o ajuste nuevo
-- del repo te sigue llegando y solo pierdes el control de lo que pones tu.
local function cargar_user()
    local home = os.getenv("HOME") or ""
    local candidatas = {
        home .. "/.config/hypr/user.lua",
        home .. "/.local/state/rhythm/user_edits/.config/hypr/user.lua",
    }
    for _, ruta in ipairs(candidatas) do
        local f = io.open(ruta, "r")
        if f then
            f:close()
            local chunk, err = loadfile(ruta)
            if chunk then
                local ok, e = pcall(chunk)
                if not ok then
                    -- Un error tuyo no debe tumbar el escritorio entero: solo
                    -- se avisa y se sigue con la base.
                    print("[hyprland] user.lua error: " .. tostring(e))
                end
            else
                print("[hyprland] user.lua ilegible: " .. tostring(err))
            end
            return
        end
    end
end

cargar_user()
