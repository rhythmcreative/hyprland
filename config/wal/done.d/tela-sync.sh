#!/bin/bash

# Hook de pywal que se ejecuta después de generar un esquema de colores
# Este script ejecuta el sincronizador de temas Tela Circle

# Ejecutar el sincronizador de temas
if [[ -x "$HOME/.local/bin/pywal-tela-sync" ]]; then
    echo "Ejecutando PywalSync-Tela..."
    "$HOME/.local/bin/pywal-tela-sync"
else
    echo "Error: pywal-tela-sync no encontrado o no es ejecutable"
fi
