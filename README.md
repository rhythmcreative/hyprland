# Rhythm Arch System Dotfiles

Este repositorio contiene la configuración completa de mi sistema Arch Linux, optimizada para productividad, estética y fluidez. No es solo una config de Hyprland; es un ecosistema completo sincronizado.

## 🚀 Componentes Principales

- **Window Manager**: Hyprland (con soporte para monitores dinámicos vía `nwg-displays`).
- **Barra**: Waybar (tematizada y sincronizada con Pywal).
- **Lanzador**: Rofi (temas personalizados adaptativos).
- **Colores**: Pywal (sincronización total entre terminal, Hyprland, Waybar y SDDM).
- **Wallpapers**: Awww (soporte nativo para GIFs animados).
- **Energía**: Gestión inteligente de batería (soporte para Single/Dual/Plugged) con selector rápido.
- **Login**: SDDM (Tema Astronaut sincronizado dinámicamente con el wallpaper).
- **Terminal**: Warp (Principal) y Kitty (Alternativa).

## 🛠️ Instalación

El instalador automatizado se encarga de todo: dependencias, respaldos y configuración.

1. **Clonar/Descargar la carpeta**:
   ```bash
   cd Hyprland
   ```

2. **Ejecutar el instalador**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

### ¿Qué hace el script?
1. **Instala Dependencias**: Tanto de repositorios oficiales como del AUR (instala `yay` si es necesario).
2. **Crea Respaldos**: Mueve tus archivos actuales a `~/dots_backup_[fecha]` para seguridad.
3. **Despliega Archivos**: Copia configuraciones, scripts, wallpapers y temas.
4. **Configura SDDM**: Instala el `root-helper` en `/usr/local/bin` y configura el tema `astronaut`.
5. **Sudoers (Opcional)**: Permite que el sistema sincronice el wallpaper de SDDM sin pedir contraseña cada vez.

## ⌨️ Atajos de Teclado (Básicos)

- `Super + T`: Warp Terminal
- `Super + E`: Dolphin (Explorador de archivos)
- `Super + R`: Rofi (Lanzador)
- `Super + Shift + W`: Selector de Wallpaper (Selector inteligente adaptativo)
- `Super + Shift + E`: Ciclar modo de batería (Single / Dual / PC Mode)
- `Super + Q`: Cerrar Ventana
- `Super + M`: Salir (Power Menu)
- `Super + Tab`: Cambiar entre ventanas

## 📁 Estructura del Repositorio

- `.config/`: Configuraciones de aplicaciones.
- `.local/bin/`: El "motor" del sistema (scripts de sincronización, carga de wallpapers, etc.).
- `Pictures/Wallpapers/`: Tu colección de GIFs y fondos.
- `.themes/`: Temas GTK personalizados.

---
*Configuración generada y auditada para garantizar el funcionamiento correcto de todos los scripts de sincronización.*
