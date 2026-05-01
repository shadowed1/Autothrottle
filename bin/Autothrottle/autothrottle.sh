#!/bin/bash
# Autothrottle core
# shadowed1
CONFIG="$HOME/Library/Application Support/Autothrottle/config"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

PID_FILE="/tmp/autothrottle.pid"
echo $$ > "$PID_FILE"

THRESHOLD="${THRESHOLD:-0.958}"
COOLDOWN="${COOLDOWN:-120}"
IDLE_THRESHOLD="${IDLE_THRESHOLD:-90}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-50}"
TRIGGER_COUNT="${TRIGGER_COUNT:-3}"

APP_PATH="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BRIGHTNESS="$APP_PATH/autothrottle_brightness"

if [[ ! -x "$BRIGHTNESS" ]]; then
    echo "Warning: brightness binary not found - display brightness will not be managed"
    BRIGHTNESS=""
fi

LOW_POWER=0
PIPEFILE=$(mktemp -u /tmp/powermetrics.XXXXXX)
mkfifo "$PIPEFILE"
BRIGHT_FILE="/tmp/autothrottle_brightness_current"
BRIGHT_FREEZE_UNTIL="/tmp/autothrottle_bright_freeze_until"
rm -f "$BRIGHT_FREEZE_FLAG" "$BRIGHT_FILE"
MONITOR_PID=""
HOLD_PID=""
SAVED_BRIGHT=""

freeze_brightness_updates() {
    date +%s > "$BRIGHT_FREEZE_UNTIL"
}

is_brightness_frozen() {
    [[ -f "$BRIGHT_FREEZE_UNTIL" ]] || return 1
    local now freeze_until
    now=$(date +%s)
    freeze_until=$(cat "$BRIGHT_FREEZE_UNTIL")
    (( now - freeze_until < 3 ))
}

read_brightness_now() {
    local b
    b=$("$BRIGHTNESS" 2>/dev/null)
    if [[ -n "$b" ]]; then
        echo "$b"
    elif [[ -f "$BRIGHT_FILE" ]]; then
        cat "$BRIGHT_FILE"
    fi
}

start_brightness_hold() {
    local target="$1"
    "$BRIGHTNESS" "$target"
    # double apply trick
    "$BRIGHTNESS" "$target"
    "$BRIGHTNESS" --hold "$target" &
    HOLD_PID=$!
    sleep 0.02
}

stop_brightness_hold() {
    local target="$1"
    if [[ -n "$HOLD_PID" ]]; then
        kill "$HOLD_PID" 2>/dev/null
        wait "$HOLD_PID" 2>/dev/null
        HOLD_PID=""
    fi
    [[ -n "$target" ]] && "$BRIGHTNESS" "$target"
}

get_user_brightness() {
    local b
    b=$(read_brightness_now)
    if [[ -z "$b" ]]; then
        "$BRIGHTNESS" 2>/dev/null
    else
        echo "$b"
    fi
}

cleanup() {
    echo ""
    echo "Cleaning up..."
    exec 3<&-
    kill "$METRICS_PID" 2>/dev/null
    kill "$MONITOR_PID" 2>/dev/null

    sudo pmset -a lowpowermode 0

    if [[ -n "$HOLD_PID" ]]; then
        kill "$HOLD_PID" 2>/dev/null
        wait "$HOLD_PID" 2>/dev/null
        HOLD_PID=""
    fi

    sleep 0.02

    if [[ -n "$BRIGHTNESS" ]]; then
        local saved
        saved=$(read_brightness_now)
        [[ -n "$saved" ]] && "$BRIGHTNESS" "$saved"
    fi

    rm -f "$PIPEFILE" "$PID_FILE" "$BRIGHT_FILE" "$BRIGHT_FREEZE_FLAG"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

reload_config() {
    echo "Reloading config..."
    unset THRESHOLD COOLDOWN IDLE_THRESHOLD LOAD_THRESHOLD TRIGGER_COUNT
    [[ -f "$CONFIG" ]] && source "$CONFIG"
    THRESHOLD="${THRESHOLD:-0.96}"
    COOLDOWN="${COOLDOWN:-60}"
    IDLE_THRESHOLD="${IDLE_THRESHOLD:-90}"
    LOAD_THRESHOLD="${LOAD_THRESHOLD:-50}"
    TRIGGER_COUNT="${TRIGGER_COUNT:-3}"
    LIMIT=$(echo "$PEAK * $THRESHOLD" | bc | cut -d'.' -f1)
    echo "New threshold: ${LIMIT} MHz | Cooldown: ${COOLDOWN}s | Trigger: ${TRIGGER_COUNT}"
}
trap reload_config SIGHUP

echo
echo "Detecting peak P-core frequency..."
PEAK=$(sudo powermetrics --samplers cpu_power -n 1 2>/dev/null \
    | grep "P-Cluster HW active residency" \
    | grep -o '[0-9]\+ MHz' \
    | awk '{print $1}' \
    | sort -n \
    | tail -1)

if [[ -z "$PEAK" ]]; then
    echo "Failed to detect peak frequency, falling back to 3.2 GHz."
    PEAK=3200
fi

echo "Detected peak: ${PEAK} MHz"
LIMIT=$(echo "$PEAK * $THRESHOLD" | bc | cut -d'.' -f1)
echo "Throttle threshold: ${LIMIT} MHz"
echo
echo "$PEAK" > /tmp/autothrottle_peak

sudo powermetrics --samplers cpu_power -i 5000 > "$PIPEFILE" 2>/dev/null &
METRICS_PID=$!
echo "powermetrics running (PID $METRICS_PID)"
echo

if [[ -n "$BRIGHTNESS" ]]; then
    "$BRIGHTNESS" --monitor "$BRIGHT_FILE" "$BRIGHT_FREEZE_FLAG" &
    MONITOR_PID=$!
    echo "Brightness monitor running (PID $MONITOR_PID)"
    sleep 0.02
    echo
fi

exec 3< "$PIPEFILE"
THROTTLE_STRIKES=0

while true; do

    SAMPLE=""
    while IFS= read -r line <&3; do
        SAMPLE+="$line"$'\n'
        [[ "$line" == \*\*\** ]] && break
    done

    FREQ=$(echo "$SAMPLE" | grep "P-Cluster HW active frequency" | awk '{print $5}')
    IDLE=$(echo "$SAMPLE" | grep "P-Cluster idle residency" | awk '{print $4}' | tr -d '%')

    if [[ -z "$FREQ" || -z "$IDLE" ]]; then
        continue
    fi

    IDLE_INT=${IDLE%.*}
    printf "[%s] Freq: %4s MHz | Idle: %6s%% | Limit: %4s MHz | Strikes: %s\n" \
        "$(date +%H:%M:%S)" "$FREQ" "$IDLE" "$LIMIT" "$THROTTLE_STRIKES"

    if (( IDLE_INT > IDLE_THRESHOLD )); then
        echo "System idling..."
        THROTTLE_STRIKES=0
        continue
    fi

    if (( FREQ < LIMIT && IDLE_INT < LOAD_THRESHOLD )); then
        (( THROTTLE_STRIKES++ ))
    else
        THROTTLE_STRIKES=0
    fi

    if (( THROTTLE_STRIKES >= TRIGGER_COUNT && LOW_POWER == 0 )); then

        echo
        echo "Throttling confirmed - Enabling Low Power Mode"

        SAVED_BRIGHT=$(get_user_brightness)
        echo "Saving brightness: $SAVED_BRIGHT"

        "$BRIGHTNESS" "$SAVED_BRIGHT"
        "$BRIGHTNESS" "$SAVED_BRIGHT"
        "$BRIGHTNESS" --hold "$SAVED_BRIGHT" &
        HOLD_PID=$!
        freeze_brightness_updates
        sleep 0.5

        sudo pmset -a lowpowermode 1
        sleep 3

        stop_brightness_hold "$SAVED_BRIGHT"
        rm -f "$BRIGHT_FREEZE_UNTIL"

        LOW_POWER=1
        THROTTLE_STRIKES=0

        sleep "$COOLDOWN"

        echo
        echo "Cooldown elapsed - Disabling Low Power Mode"

        SAVED_BRIGHT=$(get_user_brightness)
        echo "Restoring brightness: $SAVED_BRIGHT"

        "$BRIGHTNESS" "$SAVED_BRIGHT"
        "$BRIGHTNESS" "$SAVED_BRIGHT"
        "$BRIGHTNESS" --hold "$SAVED_BRIGHT" &
        HOLD_PID=$!
        freeze_brightness_updates
        sleep 0.5

        sudo pmset -a lowpowermode 0
        sleep 3.0

        stop_brightness_hold "$SAVED_BRIGHT"
        rm -f "$BRIGHT_FREEZE_UNTIL"

        LOW_POWER=0
        SAVED_BRIGHT=""

        LOW_POWER=0
        SAVED_BRIGHT=""

        while IFS= read -r -t 1 line <&3; do :; done
    fi
done
