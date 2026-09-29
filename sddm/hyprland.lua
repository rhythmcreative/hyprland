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
-- Sin reglas de monitor a proposito. Hyprland coloca las salidas solo, y eso
-- es justo lo que hace falta aqui: el problema que motivo este cambio es que
-- el servidor X del greeter solo consecguia encender el panel del portatil,
-- porque el monitor externo cuelga de la otra GPU (la NVIDIA) y Xorg con el
-- driver propietario no sabia manejar las dos a la vez. Hyprland habla con DRM
-- directamente y ya conduce las dos sin problema en la sesion normal, asi que
-- el login deja de depender de ese limite.

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
