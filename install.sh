#!/bin/bash
# Quick install script for linux-focus-tools

set -e

echo "Installing linux-focus-tools..."
echo ""

# --- Configuration prompts ---
read -rp "Daily gaming time limit in minutes [60]: " LIMIT_MINUTES
LIMIT_MINUTES=${LIMIT_MINUTES:-60}

read -rp "Hour of day to reset gaming time (0-23) [6]: " RESET_HOUR
RESET_HOUR=${RESET_HOUR:-6}

read -rp "Hour of day to shut down the system (0-23) [23]: " SHUTDOWN_HOUR
SHUTDOWN_HOUR=${SHUTDOWN_HOUR:-23}

echo ""
echo "Configuration:"
echo "  Gaming limit : ${LIMIT_MINUTES} minutes/day"
echo "  Reset hour   : ${RESET_HOUR}:00"
echo "  Shutdown hour: ${SHUTDOWN_HOUR}:00"
echo ""

# --- Steam limiter ---
mkdir -p ~/.local/bin ~/.config/systemd/user
cp steam-limiter.sh ~/.local/bin/steam-limiter.sh
chmod +x ~/.local/bin/steam-limiter.sh

# Write service file with configured values
cat > ~/.config/systemd/user/steam-limiter.service << EOF
[Unit]
Description=Steam playtime limiter
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/steam-limiter.sh
Restart=always
RestartSec=10
Environment=LIMIT_MINUTES=${LIMIT_MINUTES}
Environment=POLL_SECONDS=10
Environment=RESET_HOUR=${RESET_HOUR}

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable steam-limiter.service
systemctl --user restart steam-limiter.service

echo "Steam limiter installed and started."

# Strip a marked block from a crontab dump (stdin → stdout)
strip_cron_block() {
    awk '/^# BEGIN linux-focus-tools$/{skip=1} /^# END linux-focus-tools$/{skip=0; next} !skip'
}

# --- Crontab: shutdown warnings (user) ---
# Warnings at -10, -5, -1 minutes before shutdown (assumes shutdown is at :00)
WARN_HOUR=$(( SHUTDOWN_HOUR == 0 ? 23 : SHUTDOWN_HOUR - 1 ))
UID_VAL=$(id -u)

(
    crontab -l 2>/dev/null | strip_cron_block
    echo "# BEGIN linux-focus-tools"
    echo "50 ${WARN_HOUR} * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_VAL}/bus notify-send -u critical \"Shutdown in 10 minutes\" \"System will shut down at ${SHUTDOWN_HOUR}:00\""
    echo "55 ${WARN_HOUR} * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_VAL}/bus notify-send -u critical \"Shutdown in 5 minutes\" \"System will shut down at ${SHUTDOWN_HOUR}:00\""
    echo "59 ${WARN_HOUR} * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_VAL}/bus notify-send -u critical \"Shutdown in 1 minute\" \"System will shut down at ${SHUTDOWN_HOUR}:00\""
    echo "# END linux-focus-tools"
) | crontab -
echo "User crontab entries updated."

# --- Crontab: shutdown (root) ---
(
    sudo crontab -l 2>/dev/null | strip_cron_block
    echo "# BEGIN linux-focus-tools"
    echo "0 ${SHUTDOWN_HOUR} * * * /sbin/shutdown -h now"
    echo "# END linux-focus-tools"
) | sudo crontab -
echo "Root crontab entry updated."

echo ""
echo "To check steam-limiter logs:"
echo "  journalctl --user -u steam-limiter.service -f"
