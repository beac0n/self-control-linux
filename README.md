# linux-focus-tools

A small collection of tools to enforce healthier computer habits on Linux. Built for Arch Linux with i3, but should work on any systemd-based distro.

## What's included

### 1. Steam game time limiter (`steam-limiter.sh`)

A systemd user service that tracks how long you've been playing Steam games and kills the game when you exceed your daily limit. Time accumulates across sessions and resets on reboot.

**How it works:**
- Detects game launch by watching for Steam's `reaper` process (`reaper.*SteamLaunch AppId=`)
- Tracks accumulated playtime in `/tmp/steam-game-limiter.state` (survives service restarts, resets on reboot)
- When a game is running, polls every 10 seconds and updates elapsed time
- Sends desktop notifications at 10, 5, and 1 minute remaining
- Kills the game by finding all descendant processes of `reaper` and sending SIGTERM, then SIGKILL after 5 seconds
- Works for both native Linux games (e.g. Project Zomboid) and Proton/Wine games (e.g. After Inc.)
- Pauses the timer when no game is running, resumes on next launch

**State file format** (`/tmp/steam-game-limiter.state`):
```
accumulated_seconds session_start warned_10 warned_5 warned_1
```

### 2. Shutdown scheduler

Automatically shuts down the system at a configured time with desktop notification warnings beforehand. Useful for enforcing a consistent bedtime.

**How it works:**
- User crontab sends `notify-send` desktop notifications at 10, 5, and 1 minute before shutdown
- Root crontab runs `/sbin/shutdown -h now` at the configured time
- Shutdown can be cancelled with `sudo shutdown -c` if needed (intentionally not hard-blocked)

## Installation

### Steam game time limiter

```bash
# Install the script
cp steam-limiter.sh ~/.local/bin/steam-limiter.sh
chmod +x ~/.local/bin/steam-limiter.sh

# Install the systemd user service
cp steam-limiter.service ~/.config/systemd/user/steam-limiter.service

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now steam-limiter.service
```

**Configuration** — override defaults by editing the service file:
```bash
systemctl --user edit steam-limiter.service
```
```ini
[Service]
Environment=LIMIT_MINUTES=60
Environment=POLL_SECONDS=10
```

**View logs:**
```bash
journalctl --user -u steam-limiter.service -f
```

**Check current state:**
```bash
cat /tmp/steam-game-limiter.state
```

### Shutdown scheduler

The crontab entries are installed automatically by `install.sh`. To adjust the shutdown time, edit your crontabs directly:

```bash
crontab -e        # user entries (notifications)
sudo crontab -e   # root entry (shutdown)
```

## Dependencies

- `systemd` (user services)
- `libnotify` (`notify-send`) for desktop notifications
- `pgrep`, `ps`, `awk` — standard on any Linux system
- `xargs`, `kill` — standard on any Linux system

## Notes

- The steam-limiter timer resets on reboot, not at midnight. If you want a daily reset without rebooting, you'd need a separate systemd timer to clear `/tmp/steam-game-limiter.state`.
- The shutdown can be cancelled with `sudo shutdown -c`. This is intentional — the friction of opening a terminal is usually enough.
- The game time limit applies to any Steam game launched via the standard Steam launcher. Games launched outside of Steam are not tracked.
- Tested on Arch Linux with i3 and Steam running Proton (Wine) and native Linux games.
