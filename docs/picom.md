# picom for Qubes OS dom0 (hyprliquid look)

Hyprland's decoration in picom 12: 18 px corners, shadow 22 px at 27%,
dual_kawase blur, and the window animations — popin from 90% on Hyprland's
"ii" curve, 300 ms in, quick curve out. Tiles also slide into place when the
layout changes.

Needs **picom 12 or newer** (`picom --version`).

## Install

In dom0, with `<qube>` holding this repository:

```bash
mkdir -p ~/.config/picom
cp ~/.config/picom/picom.conf ~/.config/picom/picom.conf.bak 2>/dev/null
qvm-run --pass-io <qube> 'cat /home/user/qubes-os-dotfiles/dom0/picom/picom.conf' > ~/.config/picom/picom.conf
less ~/.config/picom/picom.conf
pkill -x picom; picom -b
```

## Notes

- Per-window settings are in `rules`. Once `rules` exists, picom 12 ignores
  the old options (`rounded-corners-exclude`, `shadow-exclude`,
  `opacity-rule`), so add exceptions there.
- rofi gets 42 px and dunst 18 px corners: they draw their own border, and
  picom's radius has to match it.
- Window classes from qubes carry the qube name: `work:Firefox`.
- i3 hides the windows of the workspace you leave and shows the new ones, so
  the open/close animation also plays on workspace switches.
- The `geometry` animation (tiles sliding) is experimental in picom and also
  plays while dragging a floating window. Delete its block if it bothers you.
