# Configuración del Módulo de Clima para Waybar

Este script obtiene datos meteorológicos de **OpenWeatherMap** para Paracuellos de Jarama y los muestra en tu waybar con iconos apropiados.

## 🔧 Configuración Inicial

### 1. Obtener API Key de OpenWeatherMap

1. Ve a [OpenWeatherMap API](https://openweathermap.org/api)
2. Crea una cuenta gratuita
3. Ve a la sección "API keys" en tu perfil
4. Genera una nueva API key
5. Guarda tu API key (ejemplo: `abc123def456ghi789`)

### 2. Configurar la API Key

**Opción A: Usando el archivo de configuración (RECOMENDADO)**
```bash
# Edita el archivo de configuración
nano ~/.config/waybar/scripts/weather_config.sh

# Reemplaza YOUR_API_KEY_HERE con tu API key real
export OPENWEATHER_API_KEY="tu_api_key_aquí"
```

**Opción B: Variable de entorno**
```bash
# Añadir a tu ~/.bashrc o ~/.zshrc
export OPENWEATHER_API_KEY="tu_api_key_aquí"
```

### 3. Probar el Script

```bash
# Probar el script directamente
~/.config/waybar/scripts/weather.sh

# Forzar actualización
~/.config/waybar/scripts/weather.sh update
```

### 4. Reiniciar Waybar

```bash
# Reiniciar waybar para aplicar cambios
pkill waybar && nohup waybar > /dev/null 2>&1 &
```

## 🎨 Iconos Disponibles

El script usa iconos Nerd Font específicos para waybar según las condiciones meteorológicas:

- 󰓼 Cielo despejado (día)
- 󰂶 Cielo despejado (noche)
- 󰓻 Pocas nubes (día)
- 󰔀 Pocas nubes (noche)
- 󰓦 Nubes dispersas/Muy nublado
- 󰔇 Lluvia/Chubascos
- 󰔎 Tormentas
- 󰔊 Nieve
- 󰓳 Niebla/Bruma

> **Nota**: Estos iconos requieren una fuente Nerd Font instalada (ya tienes JetBrains Mono Nerd Font instalada)

## ⚙️ Configuración Avanzada

Puedes personalizar la configuración editando `weather_config.sh`:

```bash
# Cambiar ciudad
export WEATHER_CITY="Madrid"
export WEATHER_COUNTRY_CODE="ES"

# Cambiar unidades (metric/imperial)
export WEATHER_UNITS="metric"
```

## 🔍 Solución de Problemas

### Error de API Key
- Icono: 🔑
- Causa: API key inválida o no configurada
- Solución: Verifica que tu API key sea correcta

### Error de Ciudad
- Icono: 📍  
- Causa: Ciudad no encontrada
- Solución: Verifica el nombre de la ciudad

### Error de Conexión
- Icono: ❌
- Causa: Sin conexión a internet
- Solución: Verifica tu conexión a internet

## 📋 Características

- **Cache inteligente**: Los datos se cachean por 5 minutos para evitar llamadas excesivas a la API
- **Actualización automática**: Se actualiza cada 60 segundos según la configuración de waybar
- **Click para actualizar**: Haz clic en el widget para forzar una actualización
- **Tooltips informativos**: Muestra descripción y temperatura al pasar el mouse
- **Manejo de errores**: Iconos específicos para diferentes tipos de error
- **Compatible con jq**: Usa jq si está disponible para mejor parsing de JSON

## 🛠️ Dependencias

- `curl` - Para hacer peticiones HTTP (generalmente ya instalado)
- `jq` - Para parsing de JSON (opcional pero recomendado)

```bash
# Instalar jq en Arch Linux
sudo pacman -S jq
```

## 📄 Configuración de Waybar

El módulo ya está configurado en tu `~/.config/waybar/config`:

```json
"custom/weather": {
    "exec": "/home/rhythmcreative/.config/waybar/scripts/weather.sh",
    "return-type": "json",
    "format": "{}",
    "interval": 60,
    "tooltip": true,
    "on-click": "/home/rhythmcreative/.config/waybar/scripts/weather.sh update",
    "signal": 8
}
```

¡Disfruta de tu nuevo módulo de clima personalizado! 🌤️
