#!/usr/bin/env bash
# ===================================================================
# Astronaut Desktop - Uninstaller
# ===================================================================
set -e

echo "Uninstalling Astronaut Desktop customization..."

# 1. Stop and remove Conky
killall -q conky || true
rm -rf "$HOME/.config/conky/Astronaut"
rm -f "$HOME/.config/autostart/conky-astronaut.desktop"
echo "  -> Conky configuration and autostart removed."

# 2. Reset dock to bottom or left (optional prompt)
read -p "Reset dock to default Ubuntu left dock? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gsettings reset org.gnome.shell.extensions.dash-to-dock dock-position || true
    gsettings reset org.gnome.shell.extensions.dash-to-dock extend-height || true
    gsettings reset org.gnome.shell.extensions.dash-to-dock autohide || true
    echo "  -> Dock reset to default."
fi

echo "Uninstallation complete."
