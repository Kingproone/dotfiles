# Guides & References

### Plasma customizations <br />
https://store.kde.org/p/1561335/ - willow dark decorations <br />
https://store.kde.org/p/2139337 - split clock for vertical panels <br />
https://github.com/matinlotfali/KDE-Rounded-Corners - rounded corners <br />
https://github.com/vinceliuice/Tela-icon-theme - tela icons <br />
https://github.com/vinceliuice/Qogir-icon-theme/tree/master/src/cursors/dist - qogir cursors <br />
https://github.com/guiodic/material-decoration - [upstream implementation pending](https://invent.kde.org/plasma/breeze/-/merge_requests/529) - locally integrated menus <br />

<details>
<summary> Switching audio outputs in KDE Plasma with a keyboard shortcut </summary>
<br />
  
> made with claude 4.6, then cleaned up

>  my file as reference: https://github.com/Kingproone/dotfiles/blob/main/home/%24USER/.local/bin/switch-audio.sh
  
#### Step 1: Understand your setup: sinks vs. ports

Before writing any script, you need to know which problem you're solving, because the solution differs:

Separate sinks: your system exposes multiple independent audio devices (e.g., built-in speakers, a USB DAC, a Bluetooth headset, an HDMI output). Each is a distinct "sink" in PipeWire/PulseAudio.

Ports on one sink: your system has a single sound card that exposes multiple outputs as ports (e.g., "Analog Headphones" and "Analog Line Out" both live under one ALSA sink).

Run this to see what you have:
```
pactl list sinks
```

Look at the `Name:` fields and the `Ports:` sections. If you have one sink with multiple ports listed under it, you need the port-switching approach. If you have multiple sinks, you need the sink-switching approach.

#### Step 2: Find the exact names

For sink switching:
```
pactl list short sinks
```

Note the full sink name from the second column, e.g. `alsa_output.pci-0000_00_1f.3.analog-stereo`.

For port switching:
```
pactl list sinks | grep -E 'Name:|port'
```

Note both the sink name and the port identifiers, e.g. `analog-output-speaker`, `analog-output-headphones`.

#### Step 3: Create the script

Create `~/.local/bin/switch-audio.sh`, `~/.local/bin/` is the standard location for user-installed executables that don't require root.

##### Option A: Toggle between two sinks
```
#!/bin/bash

SINK1="alsa_output.pci-0000_00_1f.3.analog-stereo"
SINK2="alsa_output.pci-0000_00_1f.3.analog-headphones"

CURRENT=$(pactl get-default-sink)

if [ "$CURRENT" = "$SINK1" ]; then
    TARGET="$SINK2"
    LABEL="Headphones"
else
    TARGET="$SINK1"
    LABEL="Speakers"
fi

pactl set-sink-mute "$CURRENT" 1
pactl set-default-sink "$TARGET"
pactl list short sink-inputs | awk '{print $1}' | \
    xargs -I{} pactl move-sink-input {} "$TARGET"
sleep 0.1
pactl set-sink-mute "$TARGET" 0

notify-send "Audio output" "$LABEL" -t 1000
```

> The `move-sink-input` block is critical. Without it, apps already playing audio will stay on the old sink and continue outputting there until they're restarted.

##### Option B: Cycle through more than two sinks
```
#!/bin/bash

SINKS=(
    "alsa_output.pci-0000_00_1f.3.analog-stereo"
    "alsa_output.pci-0000_00_1f.3.analog-headphones"
    "bluez_sink.XX_XX_XX_XX_XX_XX.a2dp_sink"
)
LABELS=("Speakers" "Headphones" "Bluetooth")

CURRENT=$(pactl get-default-sink)
NEXT_INDEX=0

for i in "${!SINKS[@]}"; do
    if [ "${SINKS[$i]}" = "$CURRENT" ]; then
        NEXT_INDEX=$(( (i + 1) % ${#SINKS[@]} ))
        break
    fi
done

TARGET="${SINKS[$NEXT_INDEX]}"
LABEL="${LABELS[$NEXT_INDEX]}"

pactl set-sink-mute "$CURRENT" 1
pactl set-default-sink "$TARGET"
pactl list short sink-inputs | awk '{print $1}' | \
    xargs -I{} pactl move-sink-input {} "$TARGET"
sleep 0.1
pactl set-sink-mute "$TARGET" 0

notify-send "Audio output" "$LABEL" -t 1000
```

##### Option C: Switch ports (single sink, multiple ports)
```
#!/bin/bash

SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"
PORT1="analog-output-speaker"
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
```

> Note: port switching affects output routing at the hardware level, so there are no sink-inputs to move here — all streams on that sink follow the port change automatically.

> All the scripts have a sleep timer, this is because audio levels will be applied after switching, resulting in a pop noise, 0.1 worked for me, play around with it

#### Step 4: Make it executable and test
```
chmod +x ~/.local/bin/switch-audio.sh
./switch-audio.sh
```

Open something that's playing audio before testing, so you can confirm streams follow the switch.

#### Step 5: Assign a keyboard shortcut in System Settings

`System Settings` → `Keyboard` → `Shortcuts` → `Add New` → `Command or Script...`

1. Set the Command to the full path: `/home/yourusername/.local/bin/switch-audio.sh` (the shortcut daemon may not expand tilde correctly.)
2. Click `+ Add...` and press your desired key combination (e.g. Meta+A)
3. Click `Apply`

#### Troubleshooting

Script works in terminal but not from shortcut: use full paths to any binaries if needed (/usr/bin/pactl).

notify-send shows nothing: on some setups notify-send needs DBUS_SESSION_BUS_ADDRESS set. Add this near the top of your script:
```
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
```

Bluetooth sink not appearing: Bluetooth sinks only exist in PipeWire/PulseAudio while the device is connected. The cycle script above will skip gracefully if a sink isn't present only if you add a connectivity check; otherwise it will fall through to index 0. If you rely on Bluetooth in the rotation, add a check with `pactl list short sinks | grep -q "$TARGET"` before setting it.

</details>

### Fastfetch <br />
https://github.com/fastfetch-cli/fastfetch/wiki <br />
https://github.com/fastfetch-cli/fastfetch/tree/dev/presets <br />
https://github.com/ChrisTitusTech/mybash/blob/main/config.jsonc <br />
https://github.com/fastfetch-cli/fastfetch/discussions/1040#discussioncomment-9866131 <br />
https://www.asciiart.eu/ <br />
https://github.com/fastfetch-cli/fastfetch/issues/1847 <br />

### Bash <br />
A command listed in .bashrc will run at terminal start. <br />
https://www.cyberciti.biz/tips/howto-linux-unix-bash-shell-setup-prompt.html <br />
https://stackoverflow.com/questions/2518127/how-to-reload-bashrc-settings-without-logging-out-and-back-in-again <br />
https://unix.stackexchange.com/questions/100959/how-can-i-change-my-bash-prompt-to-show-my-working-directory <br />
https://askubuntu.com/questions/1792/how-can-i-suspend-hibernate-from-command-line <br />
https://superuser.com/questions/402246/bash-can-i-set-ctrl-backspace-to-delete-the-word-backward <br />
https://github.com/ChrisTitusTech/mybash/blob/main/.bashrc <br />
https://stackoverflow.com/questions/71459823/how-to-change-the-terminal-title-to-currently-running-process <br />
https://misc.flogisoft.com/bash/tip_colors_and_formatting <br />
https://medium.com/@adamtowers/how-to-customize-your-terminal-and-bash-profile-from-scratch-9ab079256380 <br />

### Grub <br />
Regenerate ```grub.cfg``` with:
```
sudo grub-mkconfig -o /boot/grub/grub.cfg
```
Generate font file:
```
grub-mkfont --output=outfile.pf2 --size=16 infile.ttf
```
https://www.artstation.com/artwork/oOYllO - background <br />
https://www.gnome-look.org/p/1009236 - icons, edited a bit <br />
https://wiki.archlinux.org/title/GRUB#Dual-booting <br />
https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html <br />
https://daulton.ca/2018/08/reboot-and-shutdown-options-grub/ <br />
https://askubuntu.com/questions/1513639/how-to-load-custom-fonts-in-a-grub-theme <br />
[os-prober](https://tracker.debian.org/pkg/os-prober) and [grub customizer](https://github.com/muzena/grub-customizer) died for me<br />

### No longer used

#### Alacritty <br />
https://github.com/TwiggieSmallz/Default-Alacritty-TOML-Config/blob/main/alacritty.toml <br />
https://github.com/alacritty/alacritty/pull/8494 - scrollbar pr, probably not happening, why I use Konsole <br />
