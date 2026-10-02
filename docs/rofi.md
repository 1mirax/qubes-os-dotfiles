# rofi for Qubes OS dom0 (hyprliquid look)

The fuzzel launcher from [hyprliquid-dotfiles](https://github.com/1mirax/hyprliquid-dotfiles)
(`dots/.config/fuzzel`) as rofi in dom0: a 6% white veil over blurred
background, fuzzel's colours and padding, icons, a rounded selection.

rofi draws a square window. **picom rounds its corners and blurs what is
behind it** — without picom the launcher is a flat dark box. That is also why
there is no border: picom clips the corners after rofi draws, and a border
would lose its rounded parts.

The list is dom0's application entries. Qubes creates one per app in every
qube, named `<qube>: <app>`, so typing "firefox" offers each qube's Firefox.

## Install

1. In dom0:

   ```bash
   sudo qubes-dom0-update rofi
   mkdir -p ~/.config/rofi
   qvm-run --pass-io <qube> 'cat <path>/qubes-os-dotfiles/dom0/rofi/config.rasi' > ~/.config/rofi/config.rasi
   less ~/.config/rofi/config.rasi
   ```

2. Bind it in the i3 config (replaces the default dmenu binding):

   ```
   bindsym $mod+d exec --no-startup-id rofi -show drun
   ```

The font, Inter Tab, comes from the polybar bundle. Without it rofi falls back
to the default sans font.

## picom

- Blur must be on (`blur-method = "dual_kawase"` with `backend = "glx"` is the
  good one), and `class_g = 'Rofi'` must not be in `blur-background-exclude`.
- rofi gets picom's global `corner-radius`. fuzzel used 42 px; on picom 12+ a
  rule can give rofi its own:

  ```
  rules = ( { match = "class_g = 'Rofi'"; corner-radius = 42; } );
  ```

## Security

- `drun-display-format` is `{name}` only. App names come from the qubes, and
  the default format wraps them in Pango markup.
- rofi runs the entry's `Exec` line in dom0. Qubes writes those lines itself
  (`qvm-run ... qubes.StartApp+...`); a qube can't change them.
