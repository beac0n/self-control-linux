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

# Install user crontab entries (shutdown warnings)
UID_VAL=$(id -u)
USER_CRON_MARKER="linux-focus-tools"
if crontab -l 2>/dev/null | grep -q "$USER_CRON_MARKER"; then
    echo "User crontab entries already present, skipping."
else
    (crontab -l 2>/dev/null; echo "# $USER_CRON_MARKER"; echo "50 22 * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_VAL}/bus notify-send -u critical \"Shutdown in 10 minutes\" \"System will shut down at 23:00\""; echo "55 22 * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_VAL}/bus notify-send -u critical \"Shutdown in 5 minutes\" \"System will shut down at 23:00\""; echo "59 22 * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_VAL}/bus notify-send -u critical \"Shutdown in 1 minute\" \"System will shut down at 23:00\"") | crontab -
    echo "User crontab entries added."
fi

# Install root crontab entry (shutdown)
ROOT_CRON_MARKER="linux-focus-tools"
if sudo crontab -l 2>/dev/null | grep -q "$ROOT_CRON_MARKER"; then
    echo "Root crontab entry already present, skipping."
else
    (sudo crontab -l 2>/dev/null; echo "# $ROOT_CRON_MARKER"; echo "0 23 * * * /sbin/shutdown -h now") | sudo crontab -
    echo "Root crontab entry added."
fi

echo ""
echo "To check steam-limiter logs:"
echo "  journalctl --user -u steam-limiter.service -f"
