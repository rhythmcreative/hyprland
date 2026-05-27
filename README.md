# ╔══════════════════════════════════════════════════════╗
# ║  Dotfiles de Hyprland por rhythmcreative 🚀  ║
# ╚══════════════════════════════════════════════════════╝

¡Bienvenido a mi configuración personal para Hyprland! Este repositorio contiene todos los archivos de configuración y scripts necesarios para replicar mi entorno de escritorio, un sistema altamente personalizado, dinámico y con una estética cuidada, gestionado principalmente por Pywal.

## ✨ Vista Previa

*Un vistazo a cómo se ve el escritorio en acción.*

![Desktop Preview](https://i.imgur.com/placeholder.png)

**(Para añadir tu propia vista previa, haz una captura de pantalla, súbela a un servicio como Imgur y reemplaza el enlace de arriba. O si prefieres guardarla localmente, nómbrala `PREVIEW.png` y colócala en la raíz del repositorio.)**

---

## 🔧 Componentes Principales

| Componente          | Software Utilizado                               |
| ------------------- | -------------------------------------------------- |
| **Distribución**    | Arch Linux (pero compatible con Ubuntu/Debian)   |
| **Compositor**      | [Hyprland](https://hypr.land/)                     |
| **Barra de Estado** | [Waybar](https://github.com/Alexays/Waybar)        |
| **Lanzador**        | [Rofi](https://github.com/davatorium/rofi) y [Ulauncher](https://ulauncher.io/) |
| **Terminal**        | [Kitty](https://sw.kovidgoyal.net/kitty/) y [Warp](https://www.warp.dev/) |
| **Gestor de Sesión**| [SDDM](https://github.com/sddm/sddm) con tema `sddm-astronaut-theme` |
| **Tematización**    | [Pywal](https://github.com/dylanaraps/pywal) (colores dinámicos a partir del wallpaper) |
| **Dock**            | [nwg-dock-hyprland](https://github.com/nwg-piotr/nwg-dock-hyprland) |
| **Notificaciones**  | [Mako](https://github.com/emersion/mako)           |
| **Soporte Hardware**| [asusctl](https://asus-linux.org/) para control de teclado Asus |

---

## ⚙️ Instalación

1.  **Clona este repositorio:**
    ```bash
    git clone <URL_DE_TU_REPOSITORIO>
    cd dotfiles
    ```

2.  **Ejecuta el script de instalación principal:**
    Este script instalará todos los paquetes necesarios (usando `yay` en Arch o `apt` en Ubuntu/Debian) y creará los enlaces simbólicos para tu configuración personal.
    ```bash
    ./install.sh
    ```
    *Nota: En Ubuntu, el script te avisará sobre los paquetes que necesitas compilar manualmente (como Hyprland).*

3.  **(Opcional) Configura el Gestor de Sesión (SDDM):**
    Para instalar y configurar el tema de SDDM, necesitarás ejecutar un script por separado con privilegios de administrador.
    ```bash
    sudo ./setup_sddm.sh
    ```

4.  **(Opcional) Instala tus aplicaciones adicionales:**
    He creado una guía para ayudarte a instalar tus aplicaciones de usuario (como navegadores, Steam, etc.) de forma controlada. Consulta las instrucciones en:
    ```
    MANUAL_PACKAGES.md
    ```

5.  **Reinicia:**
    Para que todos los cambios surtan efecto, reinicia tu sistema.

---

## ⌨️ Atajos de Teclado Esenciales

La tecla `SUPER` es la tecla "Windows".

| Atajo                    | Acción                                      |
| ------------------------ | ------------------------------------------- |
| `SUPER + Return`         | Abrir terminal (Kitty)                      |
| `SUPER + Shift + Return` | Abrir terminal (Warp)                       |
| `SUPER + Q`              | Cerrar ventana activa                       |
| `SUPER + A`              | Abrir lanzador de aplicaciones (Rofi)       |
| `SUPER + R`              | Abrir Rofi en modo "run" (para comandos)    |
| `SUPER + E`              | Abrir gestor de archivos (Thunar)           |
| `SUPER + L`              | Bloquear pantalla (hyprlock)                |
| `SUPER + Backspace`      | Menú de apagado/reinicio (Powermenu)        |
| `SUPER + P`              | Hacer captura de pantalla (seleccionar área)|
| `SUPER + W`              | Ventana flotante (activar/desactivar)       |
| `SUPER + D`              | Mostrar/Ocultar dock (nwg-dock)             |
| `SUPER + Space`          | Abrir Ulauncher                             |
| `SUPER + Tab`            | Vista de todos los escritorios (overview)   |
| `SUPER + Flechas`        | Mover foco entre ventanas                   |
| `SUPER + [0-9]`          | Cambiar a un escritorio virtual             |
| `SUPER + Shift + [0-9]`  | Mover ventana activa a un escritorio virtual|

---

¡Disfruta de la configuración!
