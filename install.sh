#!/usr/bin/env bash
# Link dictate + dictate-tray into ~/.local/bin, install the server unit, autostart the tray.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.config/autostart" "$HOME/.config/systemd/user"
ln -sfn "$here/dictate" "$HOME/.local/bin/dictate"
ln -sfn "$here/dictate-tray" "$HOME/.local/bin/dictate-tray"
install -m644 "$here/dictate-server.service" "$HOME/.config/systemd/user/dictate-server.service"
systemctl --user daemon-reload

cat > "$HOME/.config/autostart/dictate-tray.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Dictate tray
Comment=Tray toggle for local voice dictation
Exec=$HOME/.local/bin/dictate-tray
Icon=mic-ready
X-GNOME-Autostart-enabled=true
EOF

echo "Installed. Start the tray now with: dictate-tray &"
echo "Server (optional, keeps the model loaded): tray menu, or systemctl --user enable --now dictate-server"
