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
