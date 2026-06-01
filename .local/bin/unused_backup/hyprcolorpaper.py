#!/usr/bin/env python3
import os
import sys
import subprocess
import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GdkPixbuf, GLib, Gdk

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
CACHE_DIR = os.path.expanduser("~/.cache/wallpaper-previews")

class WallpaperBrowser(Gtk.Window):
    def __init__(self):
        super().__init__(title="HyprColorPaper")
        self.set_default_size(1000, 700)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        # Main container
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.main_vbox.set_margin_top(15)
        self.main_vbox.set_margin_bottom(15)
        self.main_vbox.set_margin_start(15)
        self.main_vbox.set_margin_end(15)
        self.add(self.main_vbox)

        # Header bar with search and colors
        self.header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.main_vbox.pack_start(self.header_box, False, False, 0)

        # Search entry
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Search wallpapers...")
        self.search_entry.connect("search-changed", self.on_search_changed)
        self.header_box.pack_start(self.search_entry, True, True, 0)

        # Color selector
        self.color_combo = Gtk.ComboBoxText()
        self.color_combo.append_text("All Colors")
        
        colors = sorted([d for d in os.listdir(WALLPAPER_DIR) if os.path.isdir(os.path.join(WALLPAPER_DIR, d))])
        for color in colors:
            self.color_combo.append_text(color.capitalize())
        
        self.color_combo.set_active(0)
        self.color_combo.connect("changed", self.on_color_changed)
        self.header_box.pack_end(self.color_combo, False, False, 0)

        # Scrolled window for the grid
        self.scrolled_window = Gtk.ScrolledWindow()
        self.scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.main_vbox.pack_start(self.scrolled_window, True, True, 0)

        # FlowBox for the grid layout
        self.flowbox = Gtk.FlowBox()
        self.flowbox.set_valign(Gtk.Align.START)
        self.flowbox.set_max_children_per_line(30)
        self.flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.scrolled_window.add(self.flowbox)

        self.all_wallpapers = []
        self.load_wallpapers()
        self.show_all()

    def load_wallpapers(self):
        self.all_wallpapers = []
        for root, dirs, files in os.walk(WALLPAPER_DIR):
            for file in files:
                if file.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                    path = os.path.join(root, file)
                    color = os.path.basename(root)
                    if color == "Wallpapers": color = "others"
                    self.all_wallpapers.append({
                        "name": file,
                        "path": path,
                        "color": color
                    })
        self.refresh_grid()

    def refresh_grid(self, search_text="", color_filter="All Colors"):
        # Clear existing
        for child in self.flowbox.get_children():
            self.flowbox.remove(child)

        count = 0
        for wp in self.all_wallpapers:
            # Filter by search
            if search_text and search_text.lower() not in wp["name"].lower():
                continue
            
            # Filter by color
            if color_filter != "All Colors" and wp["color"].lower() != color_filter.lower():
                continue

            # Create item
            button = Gtk.Button()
            button.set_relief(Gtk.ReliefStyle.NONE)
            button.connect("clicked", self.on_wallpaper_clicked, wp["path"])
            
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
            button.add(vbox)

            # Thumbnail
            img_widget = Gtk.Image()
            pixbuf = self.get_thumbnail(wp["path"])
            if pixbuf:
                img_widget.set_from_pixbuf(pixbuf)
            vbox.pack_start(img_widget, False, False, 0)

            # Label (truncated)
            label = Gtk.Label(label=wp["name"][:20] + "..." if len(wp["name"]) > 20 else wp["name"])
            label.set_ellipsize(3)
            vbox.pack_start(label, False, False, 0)

            self.flowbox.add(button)
            count += 1
            if count > 100: break # Performance limit for now

        self.flowbox.show_all()

    def get_thumbnail(self, path):
        if not os.path.exists(CACHE_DIR):
            os.makedirs(CACHE_DIR)
        
        safe_name = "".join([c if c.isalnum() else "_" for c in path])
        thumb_path = os.path.join(CACHE_DIR, f"thumb_{safe_name}.png")

        if not os.path.exists(thumb_path):
            try:
                subprocess.run(["magick", path, "-resize", "200x133^", "-gravity", "center", "-extent", "200x133", thumb_path], check=True)
            except:
                return None

        return GdkPixbuf.Pixbuf.new_from_file_at_scale(thumb_path, 200, 133, True)

    def on_search_changed(self, entry):
        self.refresh_grid(entry.get_text(), self.color_combo.get_active_text())

    def on_color_changed(self, combo):
        self.refresh_grid(self.search_entry.get_text(), combo.get_active_text())

    def on_wallpaper_clicked(self, button, path):
        subprocess.run([os.path.expanduser("~/.local/bin/setwall.sh"), path])

if __name__ == "__main__":
    win = WallpaperBrowser()
    win.connect("destroy", Gtk.main_quit)
    Gtk.main()
