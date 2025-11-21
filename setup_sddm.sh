#!/bin/bash

# Este script requiere privilegios de sudo para copiar archivos a /etc y /usr/share,
# y para habilitar el servicio de SDDM.

# Detener si no se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script con sudo."
  exit 1
fi

echo "Configurando SDDM..."

# Directorio donde se encuentra este script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 1. Copiar el tema
echo "Instalando el tema sddm-astronaut-theme..."
cp -r "$SCRIPT_DIR/sddm/themes/sddm-astronaut-theme" "/usr/share/sddm/themes/"

# 2. Copiar la configuración
echo "Aplicando la configuración del tema..."
mkdir -p /etc/sddm.conf.d
cp "$SCRIPT_DIR/sddm/sddm.conf.d/astronaut.conf" "/etc/sddm.conf.d/"

# 3. Habilitar el servicio de SDDM
echo "Habilitando el servicio de SDDM..."
systemctl enable sddm

echo "✅ Configuración de SDDM completada."
echo "SDDM se iniciará en el próximo arranque del sistema."
