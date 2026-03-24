#!/bin/bash

SINK="alsa_output.pci-0000_00_14.2.analog-stereo"
PORT1="analog-output-lineout"
PORT2="analog-output-headphones"

CURRENT_PORT=$(pactl list sinks | awk -v sink="$SINK" '
    /Name: / { found = ($2 == sink) }
    found && /Active Port/ { print $3; exit }
')

if [ "$CURRENT_PORT" = "$PORT1" ]; then
    TARGET_PORT="$PORT2"
    LABEL="Headphones"
else
    TARGET_PORT="$PORT1"
    LABEL="Speakers"
fi

pactl set-sink-mute "$SINK" 1
pactl set-sink-port "$SINK" "$TARGET_PORT"
sleep 0.1
pactl set-sink-mute "$SINK" 0

notify-send "Audio output" "$LABEL" -t 1000
