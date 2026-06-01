# Sistema Automático de Wallpapers con Hellwal

Este sistema permite cambiar automáticamente el fondo de pantalla en Hyprland y sincronizar los colores con Kitty usando `hellwal`.

## Características

- ✅ Cambio automático de wallpaper con `hellwal`
- ✅ Generación automática de colores para Hyprland y Kitty
- ✅ Daemon para cambio automático cada X minutos
- ✅ Keybindings integrados en Hyprland
- ✅ Templates personalizados para hellwal
- ✅ Recarga automática de configuraciones

## Estructura de Archivos

```
~/.local/bin/
├── change-wallpaper.sh     # Script principal para cambiar wallpaper
├── auto-wallpaper.sh       # Daemon para cambio automático
└── README.md               # Este archivo

~/.config/hellwal/templates/
├── colors.conf             # Template para Hyprland
└── colors-kitty.conf       # Template para Kitty

~/Pictures/wallpapers/      # Directorio de wallpapers
```

## Uso Manual

### Cambiar wallpaper una vez

```bash
# Cambiar a un wallpaper aleatorio
change-wallpaper.sh --random

# Cambiar a un wallpaper específico
change-wallpaper.sh imagen.jpg

# Listar wallpapers disponibles
change-wallpaper.sh --list

# Usar directorio personalizado
change-wallpaper.sh --dir ~/Images --random
```

### Sistema Automático

```bash
# Iniciar daemon (cambio cada 30 minutos por defecto)
auto-wallpaper.sh --start

# Iniciar con intervalo personalizado (15 minutos)
auto-wallpaper.sh --start --interval 15

# Ver estado del daemon
auto-wallpaper.sh --status

# Detener daemon
auto-wallpaper.sh --stop

# Reiniciar daemon
auto-wallpaper.sh --restart
```

## Keybindings en Hyprland

- `Super + W`: Cambiar wallpaper aleatorio
- `Super + Shift + W`: Ver estado del daemon automático

## Agregar Wallpapers

1. Coloca tus imágenes en `~/Pictures/wallpapers/`
2. Formatos soportados: JPG, PNG, WEBP
3. Las imágenes se seleccionarán aleatoriamente

```bash
# Ejemplo: copiar imágenes
cp ~/Downloads/*.jpg ~/Pictures/wallpapers/
cp ~/Downloads/*.png ~/Pictures/wallpapers/
```

## Configuración Automática al Inicio

Para que se inicie automáticamente con tu sesión de Hyprland:

```bash
# Habilitar servicio systemd
systemctl --user enable auto-wallpaper.service
```

## Solución de Problemas

### El wallpaper no cambia
- Verifica que `hyprpaper` esté corriendo: `pgrep hyprpaper`
- Revisa que las imágenes estén en el directorio correcto
- Verifica permisos: `ls -la ~/Pictures/wallpapers/`

### Los colores no se aplican a Kitty
- Verifica que Kitty esté corriendo: `pgrep kitty`
- Revisa el archivo de colores: `~/.config/kitty/colors.conf`
- Reinicia Kitty manualmente

### Hellwal falla
- Verifica instalación: `which hellwal`
- Revisa que la imagen sea válida: `file imagen.jpg`
- Verifica templates: `ls ~/.config/hellwal/templates/`

### Ver logs
```bash
# Ver output del daemon
journalctl --user -u auto-wallpaper.service -f
```

## Personalización

### Cambiar intervalo por defecto
Edita `auto-wallpaper.sh` y cambia `DEFAULT_INTERVAL=1800` (en segundos)

### Personalizar templates de hellwal
Edita los archivos en `~/.config/hellwal/templates/` para personalizar cómo se generan los colores.

### Agregar más aplicaciones
Modifica `change-wallpaper.sh` para incluir más aplicaciones que usen los colores generados por hellwal.

## Dependencias

- `hellwal`: Generador de colores
- `hyprpaper`: Gestor de wallpapers para Hyprland
- `kitty`: Terminal (opcional)
- `find`, `shuf`: Utilidades del sistema

## Archivos de Configuración Modificados

- `~/.config/hypr/hyprland.conf`: Keybindings y source de colores
- `~/.config/hypr/hyprpaper.conf`: Configuración de wallpaper
- `~/.config/hypr/colors.conf`: Colores generados por hellwal
- `~/.config/kitty/colors.conf`: Colores para Kitty
- `~/.bashrc`: PATH actualizado
