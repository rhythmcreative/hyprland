# Guía para Instalar Aplicaciones Adicionales

El script `install.sh` instala todas las aplicaciones **esenciales** para que la configuración de Hyprland funcione correctamente (el compositor, la barra de estado, el lanzador, etc.).

Sin embargo, no instala automáticamente todas las aplicaciones de usuario que puedas tener (navegadores, editores de código, programas de diseño, juegos, etc.). Rofi simplemente muestra las aplicaciones que ya están instaladas en tu sistema.

Aquí te explicamos cómo puedes replicar tus aplicaciones instaladas de forma manual y controlada.

## Paso 1: Genera una lista de tus paquetes instalados (en tu sistema actual)

Ejecuta el comando correspondiente a tu sistema operativo actual para guardar una lista de todos los paquetes que has instalado explícitamente.

### En Arch Linux:
```bash
pacman -Qenq > ~/lista-paquetes-arch.txt
```

### En Ubuntu/Debian:
```bash
apt-mark showmanual > ~/lista-paquetes-ubuntu.txt
```
Esto creará un archivo de texto en tu directorio home con la lista de paquetes.

## Paso 2: Instala los paquetes en tu nuevo sistema

En tu **nuevo** sistema, después de haber ejecutado el script `install.sh`:

1.  Transfiere el archivo `lista-paquetes-....txt` a tu nuevo sistema.
2.  Revisa el archivo y elimina los paquetes que no quieras o que ya se hayan instalado.
3.  Usa uno de los siguientes comandos para instalar los paquetes de la lista:

### En Arch Linux:
```bash
sudo pacman -S --needed - < lista-paquetes-arch.txt
```

### En Ubuntu/Debian:
```bash
sudo apt install $(cat lista-paquetes-ubuntu.txt)
```

Este método te da control total sobre qué aplicaciones se instalan en tu nuevo sistema, evitando instalar software innecesario.
