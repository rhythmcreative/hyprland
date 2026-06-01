#!/usr/bin/env python3
"""
Waybar Colors Sync Daemon
Sincroniza automáticamente los colores de waybar con nm-applet y otros elementos GTK
"""

import os
import sys
import time
import logging
import re
from pathlib import Path
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import subprocess
import threading

class WaybarColorSync:
    def __init__(self):
        self.home_dir = Path.home()
        self.config_dir = self.home_dir / ".config"
        self.waybar_dir = self.config_dir / "waybar"
        self.gtk3_dir = self.config_dir / "gtk-3.0"
        self.gtk4_dir = self.config_dir / "gtk-4.0"
        
        # Archivos a monitorear
        self.pywal_colors_file = self.waybar_dir / "colors-pywal.css"
        self.pywal_cache_file = self.home_dir / ".cache/wal/colors"
        
        # Archivos a actualizar
        self.nm_applet_css_gtk3 = self.gtk3_dir / "nm-applet-waybar.css"
        self.nm_applet_css_gtk4 = self.gtk4_dir / "nm-applet-waybar.css"
        self.global_colors_css = self.gtk3_dir / "global-waybar-colors.css"
        
        # Configurar logging
        self.setup_logging()
        
        # Colores actuales
        self.colors = {}
        
        # Lock para evitar actualizaciones concurrentes
        self.update_lock = threading.Lock()
        
    def setup_logging(self):
        """Configura el sistema de logging"""
        log_dir = self.home_dir / ".local/share/waybar-colors-sync"
        log_dir.mkdir(parents=True, exist_ok=True)
        
        log_file = log_dir / "waybar-colors-sync.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def extract_colors_from_pywal_css(self):
        """Extrae colores del archivo CSS de pywal"""
        colors = {}
        try:
            if not self.pywal_colors_file.exists():
                self.logger.error(f"Archivo de colores pywal no existe: {self.pywal_colors_file}")
                return colors
                
            with open(self.pywal_colors_file, 'r') as f:
                content = f.read()
                
            # Buscar definiciones de colores
            color_pattern = r'@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6});'
            matches = re.findall(color_pattern, content)
            
            for name, value in matches:
                colors[name] = value
                
            self.logger.info(f"Extraídos {len(colors)} colores del archivo CSS de pywal")
            
        except Exception as e:
            self.logger.error(f"Error extrayendo colores de pywal CSS: {e}")
            
        return colors
    
    def extract_colors_from_pywal_cache(self):
        """Extrae colores del cache de pywal como fallback"""
        colors = {}
        try:
            if not self.pywal_cache_file.exists():
                self.logger.warning(f"Cache de pywal no existe: {self.pywal_cache_file}")
                return colors
                
            with open(self.pywal_cache_file, 'r') as f:
                lines = f.readlines()
                
            # Los primeros 16 colores son color0-color15
            color_names = ['background', 'foreground'] + [f'color{i}' for i in range(16)]
            
            for i, line in enumerate(lines[:18]):  # Solo primeros 18 lines
                color_value = line.strip()
                if i < len(color_names):
                    colors[color_names[i]] = color_value
                    
            # Agregar cursor como foreground
            if 'foreground' in colors:
                colors['cursor'] = colors['foreground']
                
            self.logger.info(f"Extraídos {len(colors)} colores del cache de pywal")
            
        except Exception as e:
            self.logger.error(f"Error extrayendo colores del cache de pywal: {e}")
            
        return colors
    
    def get_colors(self):
        """Obtiene colores, primero del CSS de pywal, luego del cache"""
        colors = self.extract_colors_from_pywal_css()
        
        if not colors:
            self.logger.info("No se encontraron colores en CSS, intentando cache de pywal")
            colors = self.extract_colors_from_pywal_cache()
            
        if not colors:
            self.logger.error("No se pudieron obtener colores de ninguna fuente")
            
        return colors
    
    def generate_nm_applet_css(self, colors):
        """Genera CSS para nm-applet"""
        bg_color = colors.get('background', '#1e1e2e')
        fg_color = colors.get('foreground', '#cdd6f4')
        accent_color = colors.get('color4', '#89b4fa')  # Usando color4 como accent
        hover_color = colors.get('color8', '#45475a')
        
        timestamp = datetime.now().strftime("%a %b %d %H:%M:%S %Z %Y")
        
        css_content = f'''/* nm-applet specific styling with waybar colors - Updated {timestamp} */
/* Colors: BG={bg_color}, FG={fg_color}, Accent={accent_color} */

/* NetworkManager applet main window and popup */
.nm-applet-window,
.nm-applet,
#nm-applet,
window.background {{
    background-color: {bg_color};
    color: {fg_color};
    border: 1px solid {accent_color};
}}

/* Network menu and popup items */
.nm-applet-window menuitem,
.nm-applet menuitem,
menuitem {{
    background-color: {bg_color};
    color: {fg_color};
    padding: 8px 12px;
    border-radius: 4px;
    border: none;
}}

.nm-applet-window menuitem:hover,
.nm-applet menuitem:hover,
menuitem:hover {{
    background-color: {accent_color};
    color: {fg_color};
}}

/* Connection status indicators */
.nm-applet-window .connection-active,
.nm-applet .connection-active {{
    color: {accent_color};
    font-weight: bold;
}}

/* Separator lines */
.nm-applet-window separator,
.nm-applet separator,
separator {{
    background-color: {accent_color};
    opacity: 0.3;
}}

/* Entry fields (for passwords, etc.) */
.nm-applet-window entry,
.nm-applet entry,
entry {{
    background-color: {bg_color};
    color: {fg_color};
    border: 1px solid {accent_color};
    border-radius: 4px;
    padding: 6px;
}}

/* Buttons */
.nm-applet-window button,
.nm-applet button,
button {{
    background-color: {accent_color};
    color: {fg_color};
    border: none;
    border-radius: 4px;
    padding: 6px 12px;
}}

.nm-applet-window button:hover,
.nm-applet button:hover,
button:hover {{
    opacity: 0.8;
    background-color: {colors.get('color10', accent_color)};
}}

/* System tray icon styling */
.system-tray .nm-applet-icon {{
    color: {fg_color};
}}

/* General popup and dialog styling */
popover,
dialog {{
    background-color: {bg_color};
    color: {fg_color};
    border: 1px solid {accent_color};
}}

/* List items in network selection */
listview,
list {{
    background-color: {bg_color};
    color: {fg_color};
}}

listview row,
list row {{
    background-color: {bg_color};
    color: {fg_color};
    padding: 4px 8px;
}}

listview row:hover,
list row:hover {{
    background-color: {accent_color};
    color: {fg_color};
}}

/* Scrollbars */
scrollbar {{
    background-color: {bg_color};
}}

scrollbar slider {{
    background-color: {accent_color};
    border-radius: 10px;
}}
'''
        return css_content
    
    def generate_global_colors_css(self, colors):
        """Genera CSS global para todas las aplicaciones GTK"""
        bg_color = colors.get('background', '#1e1e2e')
        fg_color = colors.get('foreground', '#cdd6f4')
        accent_color = colors.get('color4', '#89b4fa')
        highlight_color = colors.get('color2', '#fab387')
        warning_color = colors.get('color3', '#f9e2af')
        urgent_color = colors.get('color1', '#f38ba8')
        
        timestamp = datetime.now().strftime("%a %b %d %H:%M:%S %Z %Y")
        
        css_content = f'''/* Global GTK theme to match Waybar colors - Updated {timestamp} */
/* This file ensures ALL GTK applications use Waybar colors */
/* Colors: BG={bg_color}, FG={fg_color}, Accent={accent_color} */

/* Root variables for consistent color usage */
:root {{
    --waybar-bg: {bg_color};
    --waybar-fg: {fg_color};
    --waybar-accent: {accent_color};
    --waybar-highlight: {highlight_color};
    --waybar-warning: {warning_color};
    --waybar-urgent: {urgent_color};
}}

/* Global application styling - applies to ALL GTK apps */
* {{
    background-color: {bg_color};
    color: {fg_color};
}}

window,
window.background,
window.popup,
window.dialog,
window > * {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
}}

/* Menu and popup styling */
menu,
popover,
popover.background,
popover > contents,
.menu,
.popup {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
    border: 1px solid {accent_color} !important;
}}

menuitem,
menu > menuitem {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
    padding: 8px 12px !important;
    border-radius: 4px !important;
}}

menuitem:hover,
menu > menuitem:hover {{
    background-color: {accent_color} !important;
    color: {fg_color} !important;
}}

/* Button styling */
button {{
    background-color: {accent_color} !important;
    color: {fg_color} !important;
    border: none !important;
    border-radius: 4px !important;
    padding: 6px 12px !important;
}}

button:hover {{
    background-color: {highlight_color} !important;
    opacity: 0.9 !important;
}}

/* Entry fields */
entry {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
    border: 1px solid {accent_color} !important;
    border-radius: 4px !important;
}}

/* List and tree view styling */
listview,
treeview,
list {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
}}

listview row,
treeview row,
list row {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
}}

listview row:hover,
treeview row:hover,
list row:hover,
listview row:selected,
treeview row:selected,
list row:selected {{
    background-color: {accent_color} !important;
    color: {fg_color} !important;
}}

/* Scrollbars */
scrollbar {{
    background-color: {bg_color} !important;
}}

scrollbar slider {{
    background-color: {accent_color} !important;
    border-radius: 6px !important;
}}

scrollbar slider:hover {{
    background-color: {highlight_color} !important;
}}

/* Separators */
separator {{
    background-color: {accent_color} !important;
    opacity: 0.3 !important;
}}

/* Dialog and window headers */
headerbar {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
    border-bottom: 1px solid {accent_color} !important;
}}

/* Specific targeting for nm-applet */
window[title="nm-applet"],
window[class="nm-applet"],
.nm-applet,
#nm-applet {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
}}

/* Force styles on any system tray applications */
.system-tray *,
.systray * {{
    background-color: {bg_color} !important;
    color: {fg_color} !important;
}}
'''
        return css_content
    
    def update_css_files(self):
        """Actualiza todos los archivos CSS"""
        with self.update_lock:
            self.logger.info("Iniciando actualización de archivos CSS...")
            
            # Obtener colores actuales
            new_colors = self.get_colors()
            
            if not new_colors:
                self.logger.error("No se pudieron obtener colores, abortando actualización")
                return False
            
            # Verificar si los colores han cambiado
            if new_colors == self.colors:
                self.logger.debug("Los colores no han cambiado, saltando actualización")
                return False
                
            self.colors = new_colors
            self.logger.info(f"Actualizando con colores: BG={self.colors.get('background')}, "
                           f"FG={self.colors.get('foreground')}, "
                           f"Accent={self.colors.get('color4')}")
            
            try:
                # Crear directorios si no existen
                self.gtk3_dir.mkdir(parents=True, exist_ok=True)
                self.gtk4_dir.mkdir(parents=True, exist_ok=True)
                
                # Generar y escribir CSS para nm-applet
                nm_css = self.generate_nm_applet_css(self.colors)
                
                # GTK3
                with open(self.nm_applet_css_gtk3, 'w') as f:
                    f.write(nm_css)
                self.logger.info(f"Actualizado: {self.nm_applet_css_gtk3}")
                
                # GTK4
                with open(self.nm_applet_css_gtk4, 'w') as f:
                    f.write(nm_css)
                self.logger.info(f"Actualizado: {self.nm_applet_css_gtk4}")
                
                # Generar y escribir CSS global
                global_css = self.generate_global_colors_css(self.colors)
                with open(self.global_colors_css, 'w') as f:
                    f.write(global_css)
                self.logger.info(f"Actualizado: {self.global_colors_css}")
                
                # Reiniciar nm-applet para aplicar cambios
                self.restart_nm_applet()
                
                return True
                
            except Exception as e:
                self.logger.error(f"Error actualizando archivos CSS: {e}")
                return False
    
    def restart_nm_applet(self):
        """Reinicia nm-applet para aplicar los nuevos colores"""
        try:
            # Matar proceso existente
            subprocess.run(['pkill', '-f', 'nm-applet'], 
                         stdout=subprocess.DEVNULL, 
                         stderr=subprocess.DEVNULL)
            
            # Esperar un poco
            time.sleep(0.5)
            
            # Reiniciar nm-applet en segundo plano
            subprocess.Popen(['nm-applet'], 
                           stdout=subprocess.DEVNULL, 
                           stderr=subprocess.DEVNULL)
            
            self.logger.info("nm-applet reiniciado")
            
        except Exception as e:
            self.logger.warning(f"Error reiniciando nm-applet: {e}")

class ColorFileHandler(FileSystemEventHandler):
    """Manejador de eventos para archivos de colores"""
    
    def __init__(self, sync_daemon):
        self.sync_daemon = sync_daemon
        
    def on_modified(self, event):
        if event.is_directory:
            return
            
        file_path = Path(event.src_path)
        
        # Solo procesar archivos de colores relevantes
        if (file_path.name == "colors-pywal.css" or 
            file_path.name == "colors" and ".cache/wal" in str(file_path)):
            
            self.sync_daemon.logger.info(f"Detectado cambio en: {file_path}")
            # Esperar un poco para que el archivo se complete
            time.sleep(0.2)
            self.sync_daemon.update_css_files()

def main():
    """Función principal del daemon"""
    daemon = WaybarColorSync()
    
    # Actualización inicial
    daemon.logger.info("Iniciando Waybar Colors Sync Daemon")
    daemon.update_css_files()
    
    # Configurar observador de archivos
    event_handler = ColorFileHandler(daemon)
    observer = Observer()
    
    # Monitorear directorio de waybar
    observer.schedule(event_handler, str(daemon.waybar_dir), recursive=False)
    
    # Monitorear cache de pywal
    wal_cache_dir = daemon.home_dir / ".cache/wal"
    if wal_cache_dir.exists():
        observer.schedule(event_handler, str(wal_cache_dir), recursive=False)
    
    observer.start()
    daemon.logger.info("Daemon iniciado, monitoreando cambios en archivos de colores")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        daemon.logger.info("Deteniendo daemon...")
        observer.stop()
    
    observer.join()
    daemon.logger.info("Daemon detenido")

if __name__ == "__main__":
    main()
