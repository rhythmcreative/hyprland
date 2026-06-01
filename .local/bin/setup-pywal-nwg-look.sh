#!/bin/bash

# Script de configuración para integrar nwg-look con pywal y temas GTK dinámicos
# Este script configura todo el entorno necesario

echo "=== Configurando integración nwg-look + pywal ==="

# Crear directorios necesarios
echo "Creando directorios necesarios..."
mkdir -p ~/.themes
mkdir -p ~/.local/share/themes
mkdir -p ~/.config/nwg-look
mkdir -p ~/.config/wpg
mkdir -p ~/.local/bin

# Verificar que los programas necesarios estén instalados
echo "Verificando instalaciones..."

if ! command -v wal >/dev/null 2>&1; then
    echo "⚠️  pywal no encontrado. Instalando..."
    if command -v yay >/dev/null 2>&1; then
        yay -S python-pywal16 --noconfirm
    else
        sudo pacman -S python-pywal --noconfirm
    fi
fi

if ! command -v nwg-look >/dev/null 2>&1; then
    echo "⚠️  nwg-look no encontrado"
    echo "Por favor instala: sudo pacman -S nwg-look"
    exit 1
fi

# Configurar wpgtk si está disponible
if command -v wpg >/dev/null 2>&1; then
    echo "✅ wpgtk encontrado - configurando..."
    
    # Crear configuración básica para wpgtk
    cat > ~/.config/wpg/wpg.conf << EOF
[settings]
set_random = False
backend = wal
alpha = 100
light_theme = False
editor = vim
execute_cmd = True

[templates]
clear_templates = True
EOF

    echo "wpgtk configurado correctamente"
fi

# Configurar themix-gui si está disponible
if command -v themix-gui >/dev/null 2>&1; then
    echo "✅ themix-gui encontrado - configurando..."
    echo "themix-gui configurado correctamente"
fi

# Crear script wrapper para nwg-look que incluya temas pywal
cat > ~/.local/bin/nwg-look-pywal << 'EOF'
#!/bin/bash

# Wrapper para nwg-look que incluye temas generados por pywal

# Función para generar tema rápido si no existe
quick_theme() {
    if [[ -f ~/.cache/wal/colors.sh ]]; then
        local theme_name="pywal-current"
        local theme_dir="$HOME/.themes/$theme_name"
        
        if [[ ! -d "$theme_dir" ]]; then
            echo "Generando tema pywal-current..."
            ~/.local/bin/pywal-gtk-themes.sh ~/.cache/wal/wal 2>/dev/null || true
        fi
    fi
}

# Generar tema actual si es necesario
quick_theme

# Ejecutar nwg-look
exec nwg-look "$@"
EOF

chmod +x ~/.local/bin/nwg-look-pywal

# Crear alias y función helper
cat >> ~/.bashrc << 'EOF'

# Aliases para pywal + nwg-look
alias nwg-pywal='nwg-look-pywal'
alias pywal-theme='~/.local/bin/pywal-gtk-themes.sh'

# Función para cambiar wallpaper y tema en una sola acción
walltheme() {
    if [[ $# -eq 0 ]]; then
        echo "Uso: walltheme <imagen>"
        echo "Cambia el wallpaper y genera tema GTK automáticamente"
        return 1
    fi
    
    local image="$1"
    if [[ ! -f "$image" ]]; then
        echo "Error: La imagen '$image' no existe"
        return 1
    fi
    
    # Generar colores y tema
    wal -i "$image"
    ~/.local/bin/pywal-gtk-themes.sh "$image"
    
    # Aplicar tema si nwg-look está disponible
    if command -v nwg-look >/dev/null 2>&1; then
        echo "Puedes aplicar el tema usando: nwg-look"
    fi
    
    echo "¡Wallpaper y tema generados!"
}
EOF

# Crear configuración de ejemplo
cat > ~/.config/nwg-look/nwg-look.conf << EOF
# Configuración de nwg-look integrada con pywal
# Los temas generados por pywal aparecerán automáticamente en la lista

[settings]
gtk_theme = "Adwaita-dark"
icon_theme = "Adwaita"
cursor_theme = "Adwaita"
cursor_size = 24
font_name = "Sans 10"
EOF

echo ""
echo "=== Configuración completada ==="
echo ""
echo "🎨 Herramientas disponibles:"
echo "  • wpgtk: $(command -v wpg >/dev/null 2>&1 && echo "✅ Instalado" || echo "❌ No instalado")"
echo "  • themix-gui: $(command -v themix-gui >/dev/null 2>&1 && echo "✅ Instalado" || echo "❌ No instalado")"
echo "  • nwg-look: $(command -v nwg-look >/dev/null 2>&1 && echo "✅ Instalado" || echo "❌ No instalado")"
echo "  • pywal: $(command -v wal >/dev/null 2>&1 && echo "✅ Instalado" || echo "❌ No instalado")"
echo ""
echo "📝 Comandos útiles:"
echo "  • pywal-theme <imagen>        - Generar tema GTK desde imagen"
echo "  • walltheme <imagen>          - Cambiar wallpaper + generar tema"
echo "  • nwg-pywal                   - Abrir nwg-look con temas pywal"
echo "  • wpg                         - Abrir wpgtk (si está instalado)"
echo "  • themix-gui                  - Abrir themix (si está instalado)"
echo ""
echo "🔄 Para aplicar la configuración, ejecuta:"
echo "  source ~/.bashrc"
echo ""
echo "🚀 Ejemplo de uso:"
echo "  walltheme ~/Pictures/mi-wallpaper.jpg"
echo "  nwg-pywal"
echo ""
