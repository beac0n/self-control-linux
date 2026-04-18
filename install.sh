#!/bin/bash
# Quick install script for linux-focus-tools

set -e

echo "Installing linux-focus-tools..."

# Steam limiter
mkdir -p ~/.local/bin ~/.config/systemd/user
cp steam-limiter.sh ~/.local/bin/steam-limiter.sh
chmod +x ~/.local/bin/steam-limiter.sh
cp steam-limiter.service ~/.config/systemd/user/steam-limiter.service
systemctl --user daemon-reload
systemctl --user enable --now steam-limiter.service

echo "Steam limiter installed and started."
echo ""
echo "Next steps:"
echo "  1. Add shutdown crontab entries: see crontab.txt"
echo "     - User entries: crontab -e"
echo "     - Root entry:   sudo crontab -e"
echo "     - Replace UID 1000 with your UID: $(id -u)"
echo ""
echo "  2. Check steam-limiter logs:"
echo "     journalctl --user -u steam-limiter.service -f"
