#!/bin/bash
# Hook automático que se ejecuta cada vez que pywal cambia los colores
# Sincroniza automáticamente todos los componentes

# Esperar un momento para que pywal termine completamente
sleep 1

# Ejecutar sincronización completa
"$HOME"/.local/bin/sync-pywal-all

# Log del cambio
echo "$(date): Pywal sync ejecutado automáticamente" >> ~/.cache/wal/sync.log
