# qubes-os-dotfiles

The look of [hyprliquid-dotfiles](https://github.com/1mirax/hyprliquid-dotfiles)
on Qubes OS 4.3 with i3. Hyprland can't run in dom0, so the pieces are rebuilt
for X11.

![polybar](docs/polybar-preview.png)

## What is here

| | |
|---|---|
| Bar | polybar in dom0: the waybar layout, with the focused window's qube name in its label colour |
| Launcher | rofi in dom0: fuzzel's glass look and sizes 1:1, blurred by picom |
| Tray | a helper for templates that makes the tray icon background black instead of white |

```
dom0/build-polybar-dom0.sh    run in a qube with network: builds the polybar bundle
dom0/update-polybar-dom0.sh   run in dom0: updates an installed bar
dom0/rofi/config.rasi         rofi launcher config for dom0
template/install-tray-bg.sh   run as root in a template: dark tray icon background
docs/polybar.md               bar: how it works, install steps, security notes
docs/rofi.md                  launcher: install steps, picom settings
```

## Install

dom0 has no network. Everything is built or downloaded in a qube, then copied
into dom0. **Read every script in dom0 before running it** — a compromised qube
could show you one file and send another.

Steps are in [docs/polybar.md](docs/polybar.md#install) and [docs/rofi.md](docs/rofi.md#install).

## Security

- Window titles come from qubes and are untrusted. They are sanitised so they
  can't run commands in dom0 through polybar's `%{...}` tags.
- The qube name and colour come from dom0, never from the title.
- No network data enters dom0. The only download, Symbols Nerd Font, is pinned
  to one SHA-256.
