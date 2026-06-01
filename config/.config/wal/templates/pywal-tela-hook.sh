#!/bin/bash

# Hook para ejecutar pywal-tela-sync automáticamente después de Pywal
# Este script será ejecutado automáticamente por Pywal después de generar colores

# Esperar un poco para que Pywal termine completamente
sleep 2

# Ejecutar pywal-tela-sync en background para no bloquear Pywal
if command -v pywal-tela-sync >/dev/null 2>&1; then
    nohup pywal-tela-sync >/dev/null 2>&1 &
fi
