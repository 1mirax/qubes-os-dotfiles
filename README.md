# qubes-os-dotfiles

The look of [hyprliquid-dotfiles](https://github.com/1mirax/hyprliquid-dotfiles)
on Qubes OS 4.3 with i3. Hyprland can't run in dom0, so the pieces are rebuilt
for X11.

![polybar](docs/polybar-preview.png)

## Stack

| | | Why this one |
|---|---|---|
| Window manager | **i3** | Tiling, officially supported by Qubes: label-coloured borders out of the box. Hyprland and Sway can't run in dom0 (no Wayland there). |
| Compositor | **picom** | The only one in Fedora with blur, rounded corners and, from v12, animations. |
| Bar | **polybar** | Has a tray, which Qubes needs for its widgets and qube applets. |
| Launcher | **rofi** | Runs only while open; script mode makes the qube → app menu. |
| Notifications | **dunst** | Light, no notification centre, and shows qube text as plain text only. |

Everything is installed from dom0's signed Fedora repositories.

## What is here

| | |
|---|---|
| Bar | polybar in dom0: the waybar layout, with the focused window's qube name in its label colour |
| Launcher | rofi in dom0: pick a qube, then its app; fuzzel's sizes, dark glass blurred by picom |
| Notifications | dunst in dom0: mako's look, plain text only |
| Tray | a helper for templates that makes the tray icon background black instead of white |

```
dom0/build-polybar-dom0.sh    run in a qube with network: builds the polybar bundle
dom0/update-polybar-dom0.sh   run in dom0: updates an installed bar
dom0/rofi/config.rasi         rofi launcher theme for dom0
dom0/rofi/qubes-menu.py       launcher list: qubes first, then the chosen qube's apps
dom0/dunst/dunstrc            notifications for dom0
dom0/picom/picom.conf         blur, corners, shadows and window animations
dom0/power/lid-poweroff.conf  close the lid: power off
template/install-tray-bg.sh   run as root in a template: dark tray icon background
docs/polybar.md               bar: how it works, install steps, security notes
docs/rofi.md                  launcher: install steps, picom settings
docs/dunst.md                 notifications: install steps, picom settings
docs/picom.md                 compositor: install steps, notes
docs/power.md                 lid power-off, idle lock, the stay-awake button
```

## Install

dom0 has no network. Everything is built or downloaded in a qube, then copied
into dom0. **Read every script in dom0 before running it** — a compromised qube
could show you one file and send another.

Steps are in [docs/polybar.md](docs/polybar.md#install), [docs/rofi.md](docs/rofi.md#install),
[docs/dunst.md](docs/dunst.md#install), [docs/picom.md](docs/picom.md#install)
and [docs/power.md](docs/power.md).

## Security

- Window titles come from qubes and are untrusted. They are sanitised so they
  can't run commands in dom0 through polybar's `%{...}` tags.
- The qube name and colour come from dom0, never from the title.
- No network data enters dom0. The only download, Symbols Nerd Font, is pinned
  to one SHA-256.
