# SDDM Astronaut Theme - Integración con Pywal

## Descripción
Este es el tema SDDM Astronaut modificado con integración completa de **pywal**. El tema se sincroniza automáticamente con tu wallpaper actual y extrae los colores usando pywal para crear una experiencia visual coherente.

## Características
- ✨ **Sincronización automática con pywal**: Los colores del tema se actualizan automáticamente cuando cambias tu wallpaper
- 🖼️ **Background dinámico**: Usa tu wallpaper actual como fondo de la pantalla de login
- 🎨 **Extracción inteligente de colores**: Extrae automáticamente colores complementarios de tu wallpaper
- 🔄 **Hooks automáticos**: Se actualiza automáticamente cuando ejecutas `wal -i imagen.jpg`
- 🛠️ **Fácil instalación**: Script de instalación automatizada

## Requisitos
- **pywal** (`python-pywal` en Arch Linux)
- **ImageMagick** (opcional, para mejor procesamiento de imágenes)
- **SDDM** como display manager
- **Permisos sudo** para configuración

## Instalación Rápida

### Opción 1: Instalación Automática (Recomendada)
```bash
# Instalar tema con integración completa de pywal
sudo ./install-pywal-integration.sh install
```

### Opción 2: Instalación Manual
```bash
# 1. Instalar dependencias (Arch Linux)
sudo pacman -S python-pywal imagemagick

# 2. Copiar tema a directorio de SDDM
sudo cp -r . /usr/share/sddm/themes/sddm-astronaut-theme

# 3. Configurar SDDM para usar el tema
echo "[Theme]" | sudo tee -a /etc/sddm.conf
echo "Current=sddm-astronaut-theme" | sudo tee -a /etc/sddm.conf

# 4. Configurar permisos para sincronización automática
echo "$USER ALL=(root) NOPASSWD: /usr/share/sddm/themes/sddm-astronaut-theme/pywal-sync.sh" | sudo tee /etc/sudoers.d/sddm-pywal-sync
```

## Uso

### Sincronización Automática
Una vez instalado, el tema se sincroniza automáticamente cuando:
- Cambias tu wallpaper con `wal -i imagen.jpg`
- Inicias sesión (mediante autostart)

### Sincronización Manual
```bash
# Sincronizar con el wallpaper actual
./pywal-sync.sh

# O especificar un wallpaper
./pywal-sync.sh /ruta/al/wallpaper.jpg
```

### Comandos Útiles
```bash
# Instalar tema completo
sudo ./install-pywal-integration.sh install

# Solo sincronizar (sin instalar)
./install-pywal-integration.sh sync

# Sincronizar con wallpaper específico
./install-pywal-integration.sh sync /ruta/al/wallpaper.jpg

# Desinstalar tema
sudo ./install-pywal-integration.sh uninstall

# Reiniciar SDDM para aplicar cambios
sudo systemctl restart sddm
```

## Cómo Funciona

1. **Detección de Wallpaper**: El script detecta automáticamente tu wallpaper actual usando varios métodos:
   - nitrogen, feh, gsettings (GNOME), xfconf-query (XFCE)
   - Cache de pywal (`~/.cache/wal/wal`)

2. **Extracción de Colores**: Usa pywal para extraer una paleta de colores del wallpaper

3. **Procesamiento de Imagen**: Redimensiona y optimiza el wallpaper para SDDM

4. **Actualización de Configuración**: Genera un archivo `theme.conf` con los nuevos colores

5. **Hooks Automáticos**: Se ejecuta automáticamente cuando pywal detecta cambios

## Estructura de Archivos
```
sddm-astronaut-theme/
├── pywal-sync.sh              # Script principal de sincronización
├── install-pywal-integration.sh   # Script de instalación
├── theme.conf                 # Configuración del tema (generado automáticamente)
├── Main.qml                   # Interfaz principal del tema
├── Backgrounds/
│   ├── processed/             # Backgrounds procesados
│   │   └── current_bg_80_50.png  # Background actual (generado automáticamente)
│   └── bg.png                 # Background original
├── Components/                # Componentes QML
└── Assets/                    # Iconos y recursos
```

## Personalización

### Colores
Los colores se extraen automáticamente de tu wallpaper, pero puedes personalizar la configuración editando `theme.conf` después de la sincronización.

### Configuración Manual
Si quieres personalizar aspectos específicos, puedes editar `pywal-sync.sh` y modificar la función `generate_theme_config()`.

## Resolución de Problemas

### El tema no se actualiza automáticamente
1. Verifica que pywal esté instalado: `wal --version`
2. Verifica los permisos sudo: `sudo -l | grep pywal`
3. Ejecuta manualmente: `sudo /usr/share/sddm/themes/sddm-astronaut-theme/pywal-sync.sh`

### No se detecta el wallpaper
1. Especifica el wallpaper manualmente: `./pywal-sync.sh /ruta/al/wallpaper.jpg`
2. Verifica que tu wallpaper manager sea compatible (nitrogen, feh, gsettings, xfconf-query)

### Colores no se aplican correctamente
1. Verifica que pywal haya generado colores: `cat ~/.cache/wal/colors`
2. Regenera colores: `wal -i /ruta/al/wallpaper.jpg`
3. Ejecuta sincronización: `./pywal-sync.sh`

### SDDM no muestra el tema
1. Verifica la configuración: `cat /etc/sddm.conf | grep Current`
2. Verifica que el tema esté instalado: `ls /usr/share/sddm/themes/sddm-astronaut-theme/`
3. Reinicia SDDM: `sudo systemctl restart sddm`

## Desinstalación
```bash
sudo ./install-pywal-integration.sh uninstall
```

## Créditos
- Tema original: [Keyitdev/sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme)
- Integración pywal: rhythmcreative
- Basado en: [MarianArlt/sddm-sugar-dark](https://github.com/MarianArlt/sddm-sugar-dark)

## Licencia
Distribuido bajo la licencia GPLv3+. Ver `LICENSE` para más información.

---

**¡Disfruta de tu experiencia de login personalizada! 🚀**

# sddm-astronaut-theme

A theme for the [SDDM login manager](https://github.com/sddm/sddm).

- Screen resolution: 1080p
- Font: Open sans

### Preview

You can easily change how it looks in **[config](./theme.conf)**. 
Here are some examples:

![Preview](./Previews/preview1.png)
![Preview](./Previews/preview2.png)
![Preview](./Previews/preview3.png)
![Preview](./Previews/preview4.png)

### Dependencies

#### Arch, Void
```sh
sddm qt6-svg
```
#### Fedora
```sh
sddm qt6-qtsvg
```
#### OpenSUSE
```sh
sddm-qt6 qt6-svg
```

### Install

1. Clone this repository, copy fonts to `/usr/share/fonts/`:

   ```sh
   sudo git clone https://github.com/keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/sddm-astronaut-theme
   sudo cp /usr/share/sddm/themes/sddm-astronaut-theme/Fonts/* /usr/share/fonts/
   ```

2. Then edit `/etc/sddm.conf`, so that it looks like this:

    ```sh
    echo "[Theme]
    Current=sddm-astronaut-theme" | sudo tee /etc/sddm.conf
    ```


### Virtual keyboard

![Preview](./Previews/preview5.png)

#### Arch
1. Install package.
    ```sh
    sddm qt6-virtualkeyboard
    ```

2. Then edit `/etc/sddm.conf.d/virtualkbd.conf`, so that it looks like this:

    ```sh
    [General]
    InputMethod=qtvirtualkeyboard
    ```

### Credits

Based on the theme [`Sugar Dark for SDDM`](https://github.com/MarianArlt/sddm-sugar-dark) by **MarianArlt**.

### License

Distributed under the **[GPLv3+](https://www.gnu.org/licenses/gpl-3.0.html) License**.    
Copyright (C) 2022-2024 Keyitdev.