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
    ICON="audio-headphones"
else
    TARGET_PORT="$PORT1"
    LABEL="Speakers"
    ICON="audio-speakers"
fi

pactl set-sink-mute "$SINK" 1
pactl set-sink-port "$SINK" "$TARGET_PORT"
sleep 0.1 # this is to avoid a nasty audio pop
pactl set-sink-mute "$SINK" 0

sleep 0.5 # this is to give time for the audio level to show and avoid them flickering
busctl --user call org.kde.plasmashell /org/kde/osdService org.kde.osdService showText ss "$ICON" "Output: $LABEL"
