# Guides & References

### Plasma customizations <br />
https://store.kde.org/p/1561335/ - willow dark decorations <br />
https://store.kde.org/p/2139337 - split clock for vertical panels <br />
https://github.com/matinlotfali/KDE-Rounded-Corners - rounded corners <br />
https://github.com/vinceliuice/Tela-icon-theme - tela icons <br />
https://github.com/vinceliuice/Qogir-icon-theme/tree/master/src/cursors/dist - qogir cursors <br />
https://github.com/guiodic/material-decoration - [upstream implementation pending](https://invent.kde.org/plasma/breeze/-/merge_requests/529) - locally integrated menus <br />

### Alacritty <br />
https://github.com/TwiggieSmallz/Default-Alacritty-TOML-Config/blob/main/alacritty.toml <br />
https://github.com/alacritty/alacritty/pull/7231 <br />

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
