#!/usr/bin/env bash
# ===================================================================
# Astronaut Desktop - GNOME Settings Applicator
# ===================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Applying GNOME interface & theme settings..."

# Dark Mode & Themes
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Orchis-Dark'
gsettings set org.gnome.desktop.interface icon-theme 'Yaru-blue-dark'

# Window controls (minimize, maximize, close on the right)
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# Clean top bar clock (no distracting seconds)
gsettings set org.gnome.desktop.interface clock-show-seconds false

# Enable User Themes extension & set shell theme
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null || true
gsettings set org.gnome.shell.extensions.user-theme name 'Orchis-Dark'

# Apply Dash to Dock settings (Right position, floating pill, autohide, no panel mode)
if [ -f "$SCRIPT_DIR/dash-to-dock.dconf" ]; then
    dconf load /org/gnome/shell/extensions/dash-to-dock/ < "$SCRIPT_DIR/dash-to-dock.dconf"
fi

# Set Wallpaper
WP_PATH="$HOME/Pictures/Wallpapers/astronaut-jellyfish.jpg"
if [ -f "$WP_PATH" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$WP_PATH"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WP_PATH"
    gsettings set org.gnome.desktop.background picture-options 'zoom'
fi

echo "GNOME settings applied successfully!"
