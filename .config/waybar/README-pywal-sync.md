# Sincronización de Waybar con pywal 🎨

## ¿Qué se ha configurado?

He solucionado el problema de sincronización entre Waybar y pywal creando un sistema robusto que garantiza que los colores se actualicen correctamente.

## Scripts Creados

### 1. `~/.local/bin/waybar-pywal-reload`
Script principal que:
- ✅ Verifica que pywal haya generado los colores
- 📄 Copia los colores de pywal al archivo CSS de waybar
- 🔄 Reinicia Waybar para aplicar los colores
- 📱 Muestra notificación de confirmación

## Atajos de Teclado Configurados

### Super + Shift + W
- **Función**: Seleccionar wallpaper + sincronizar Waybar
- **Comportamiento**: 
  1. Abre el selector de wallpapers
  2. Aplica pywal al wallpaper seleccionado
  3. Automáticamente sincroniza Waybar con los nuevos colores

### Super + Shift + R  
- **Función**: Recarga manual de Waybar con sincronización pywal
- **Uso**: Cuando necesites sincronizar Waybar manualmente (por ejemplo, si cambias colores externamente)

## Cómo Funciona la Sincronización

1. **Detección de colores**: El script verifica que pywal haya generado los colores
2. **Transferencia**: Copia los colores de `~/.cache/wal/colors-waybar.css` a `~/.config/waybar/colors-pywal.css`
3. **Recarga**: Reinicia Waybar para aplicar los nuevos colores
4. **Verificación**: Confirma que Waybar esté funcionando correctamente

## Estructura de Archivos

```
~/.config/waybar/
├── config                    # Configuración principal de waybar
├── style.css                # CSS principal que importa colors-pywal.css
├── colors-pywal.css         # Colores generados por pywal (actualizado automáticamente)
└── README-pywal-sync.md     # Este archivo de documentación

~/.local/bin/
└── waybar-pywal-reload      # Script de sincronización
```

## Logs y Depuración

Los logs se guardan en: `~/.cache/waybar-pywal-reload.log`

Para ver los logs en tiempo real:
```bash
tail -f ~/.cache/waybar-pywal-reload.log
```

## Solución de Problemas

### Waybar no se sincroniza:
1. Presiona `Super + Shift + R` para forzar la sincronización
2. Revisa los logs: `cat ~/.cache/waybar-pywal-reload.log`

### Los colores no cambian:
1. Verifica que pywal esté instalado: `which wal`
2. Asegúrate de que hay un wallpaper actual: `cat ~/.cache/current-wallpaper`

### Script no funciona:
1. Verifica permisos: `ls -la ~/.local/bin/waybar-pywal-reload`
2. Debe mostrar permisos de ejecución (x)

## Beneficios de esta Configuración

- 🔄 **Sincronización automática**: Waybar se actualiza automáticamente al cambiar wallpaper
- 🛡️ **Robusto**: Maneja errores y reinicia Waybar si es necesario
- 📱 **Notificaciones**: Te informa cuando la sincronización está completa
- 🎛️ **Control manual**: Puedes forzar la recarga cuando necesites
- 📊 **Logs detallados**: Para diagnosticar cualquier problema

## Personalización Adicional

Si quieres modificar qué colores usa cada módulo de Waybar, edita:
`~/.config/waybar/style.css`

Los colores disponibles de pywal son:
- `@background`, `@foreground`
- `@color0` hasta `@color15`
- `@cursor`

¡Disfruta de tu Waybar perfectamente sincronizado con pywal! 🎨✨
