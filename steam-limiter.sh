#!/bin/bash

# Configuration (overridable via systemd environment)
LIMIT_MINUTES=${LIMIT_MINUTES:-60}
POLL_SECONDS=${POLL_SECONDS:-10}
HEARTBEAT_INTERVAL=600  # log idle heartbeat every 10 minutes
KILL_DELAY_SECONDS=10   # wait this long after game start before killing

USER_ID=$(id -u)
DISPLAY=${DISPLAY:-:0}
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_ID}/bus"

STATE_FILE="/tmp/steam-game-limiter.state"
LIMIT_SECONDS=$(( LIMIT_MINUTES * 60 ))
LAST_HEARTBEAT=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

notify() {
    log "NOTIFY: $1 — $2"
    notify-send -u critical "$1" "$2"
}

get_reaper_pid() {
    pgrep -f "reaper.*SteamLaunch AppId="
}

game_running() {
    [ -n "$(get_reaper_pid)" ]
}

get_game_descendants() {
    local reaper_pid=$1
    ps -eo pid,ppid | awk -v root="$reaper_pid" '
    BEGIN { pids[root]=1 }
    { ppids[$1]=$2 }
    END {
        changed=1
        while(changed) {
            changed=0
            for(pid in ppids) {
                if(ppids[pid] in pids && !(pid in pids)) {
                    pids[pid]=1; changed=1
                }
            }
        }
        for(pid in pids) if(pid!=root) print pid
    }'
}

remaining_minutes() {
    local remaining=$(( LIMIT_MINUTES - ACCUMULATED / 60 ))
    [ "$remaining" -lt 0 ] && remaining=0
    echo "$remaining"
}

clamp_accumulated() {
    [ "$ACCUMULATED" -gt "$LIMIT_SECONDS" ] && ACCUMULATED=$LIMIT_SECONDS
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        read -r ACCUMULATED SESSION_START WARNED_10 WARNED_5 WARNED_1 < "$STATE_FILE"
    else
        ACCUMULATED=0
        SESSION_START=0
        WARNED_10=0; WARNED_5=0; WARNED_1=0
    fi
    clamp_accumulated
}

save_state() {
    clamp_accumulated
    echo "$ACCUMULATED $SESSION_START $WARNED_10 $WARNED_5 $WARNED_1" > "$STATE_FILE"
}

flush_session() {
    ACCUMULATED=$(( ACCUMULATED + $(date +%s) - SESSION_START ))
    SESSION_START=$(date +%s)
    clamp_accumulated
}

kill_games() {
    local reaper_pid
    reaper_pid=$(get_reaper_pid)
    notify "🎮 Time's up" "Gaming limit reached. See you after reboot!"
    local pids
    pids=$(get_game_descendants "$reaper_pid")
    log "kill_games: sending TERM to PIDs: $(echo $pids | tr '\n' ' ')"
    echo "$pids" | xargs -r kill -TERM
    sleep 5
    pids=$(get_game_descendants "$reaper_pid")
    if [ -n "$pids" ]; then
        log "kill_games: sending KILL to remaining PIDs: $(echo $pids | tr '\n' ' ')"
        echo "$pids" | xargs -r kill -KILL
    else
        log "kill_games: all processes gone after TERM"
    fi
    SESSION_START=0
    save_state
}

warn_if_needed() {
    local remaining=$1
    if [ "$WARNED_1" -eq 0 ] && [ "$remaining" -le 1 ]; then
        notify "🚨 1 minute left!" "Game will be killed in 1 minute — save now!"
        WARNED_1=1; flush_session; save_state
    elif [ "$WARNED_5" -eq 0 ] && [ "$remaining" -le 5 ]; then
        notify "⚠️ 5 minutes left" "Save your progress soon!"
        WARNED_5=1; flush_session; save_state
    elif [ "$WARNED_10" -eq 0 ] && [ "$remaining" -le 10 ]; then
        notify "⚠️ 10 minutes left" "Your gaming time ends in 10 minutes."
        WARNED_10=1; flush_session; save_state
    fi
}

log "Starting steam-limiter (limit=${LIMIT_MINUTES}m, poll=${POLL_SECONDS}s)"
load_state
log "Loaded state: accumulated=${ACCUMULATED}s session_start=${SESSION_START} warned=${WARNED_10}/${WARNED_5}/${WARNED_1}"

while true; do
    NOW=$(date +%s)
    if game_running; then
        if [ "$SESSION_START" -eq 0 ]; then
            SESSION_START=$NOW
            REMAINING=$(remaining_minutes)
            log "Game started. Remaining: ${REMAINING}m"
            notify "🎮 Game started" "${REMAINING} minutes of gaming time remaining."
            save_state
        else
            SESSION_ELAPSED=$(( NOW - SESSION_START ))
            TOTAL_SECONDS=$(( ACCUMULATED + SESSION_ELAPSED ))
            TOTAL_MINUTES=$(( TOTAL_SECONDS / 60 ))
            REMAINING=$(( LIMIT_MINUTES - TOTAL_MINUTES ))
            [ "$REMAINING" -lt 0 ] && REMAINING=0

            log "Game running. elapsed=${SESSION_ELAPSED}s total=${TOTAL_MINUTES}m remaining=${REMAINING}m"

            if [ "$REMAINING" -le 0 ] && [ "$SESSION_ELAPSED" -ge "$KILL_DELAY_SECONDS" ]; then
                log "Limit reached — killing games"
                ACCUMULATED=$TOTAL_SECONDS
                SESSION_START=0
                kill_games
            else
                warn_if_needed "$REMAINING"
            fi
        fi
    else
        if [ "$SESSION_START" -ne 0 ]; then
            ACCUMULATED=$(( ACCUMULATED + NOW - SESSION_START ))
            SESSION_START=0
            log "Game stopped. Flushed accumulated=${ACCUMULATED}s"
            save_state
        elif [ $(( NOW - LAST_HEARTBEAT )) -ge "$HEARTBEAT_INTERVAL" ]; then
            log "Idle. accumulated=${ACCUMULATED}s ($(( ACCUMULATED / 60 ))m used, $(remaining_minutes)m remaining)"
            LAST_HEARTBEAT=$NOW
        fi
    fi

    sleep "$POLL_SECONDS"
done
