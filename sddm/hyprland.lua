-- Hyprland del GREETER de SDDM. Deliberadamente minimo.
--
-- SDDM arranca esto en su propia VT para pintar la pantalla de login, asi que
-- aqui NO se incluye la configuracion del usuario: sin atajos, sin autostart,
-- sin waybar, sin dock. Cargar la del usuario levantaria el escritorio entero
-- encima del login.
--
-- Lo que hace falta es lo contrario de lo habitual: apagar todo lo que pueda
-- estorbar. El logo, el splash y las animaciones salen; el fondo se deja en 0
-- para que lo pinte el tema y no la foto por defecto de Hyprland.
--
-- ESTA ES UNA PLANTILLA, no se arranca directamente. El login se pinta solo en
-- el panel del portatil, y eso no se puede escribir aqui porque tiene que ser
-- condicional: con la tapa cerrada no hay panel, y una regla que lo apagase sin
-- mirar dejaria el login sin ninguna pantalla. La condicion no se resuelve
-- dentro de la config porque esta version de Hyprland (0.56) no expone
-- getMonitors en Lua, y ademas la config se parsea mientras el backend todavia
-- se esta inicializando, donde consultar el socket seria una carrera.
--
-- El problema que motivo esto era el inverso: con las dos pantallas conectadas
-- el greeter pintaba el login en las dos. En un portatil con GPU hibrida eso
-- duplicaba el render sin ganar nada, porque el monitor externo cuelga de la
-- NVIDIA y encenderlo en el login no aporta nada: el panel ya esta ahi al lado.
--
-- La marca de mas abajo no se deja tal cual: sddm-greeter-monitor la sustituye
-- por las reglas generadas antes de arrancar Hyprland. Si este fichero llegara
-- a arrancarse sin pasar por ahi, la lista vacia deja que Hyprland aplique sus
-- modos preferidos, que no es lo que se quiere, pero al menos el login arranca
-- en vez de romperse.

-- @@MONITOR@@

-- El puntero lo dibuja Hyprland, no el greeter de SDDM: Hyprland implementa
-- wp_cursor_shape_manager_v1, asi que el cliente Qt pide una "forma" por nombre
-- y el compositor devuelve la imagen desde su propio tema. Por eso
-- CursorTheme en sddm.conf no cambia nada aqui.
--
-- Hyprland 0.55 trae enable_hyprcursor = true por defecto, que usa hyprcursor y
-- solo acepta temas .hlc; no hay ningun hyprcursor.conf en esta maquina, asi que
-- cae al tema por defecto. Con enable_hyprcursor = false vuelve al cargador
-- Xcursor clasico, que si lee XCURSOR_THEME -- que el modulo NixOS pone a
-- Bibata-Modern-Ice en el unit del display-manager. Asi el login y el escritorio
-- usan el mismo puntero.
cursor = {
    enable_hyprcursor = false,
},

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
    },

    animations = {
        enabled = false,
    },
})
