# rofi for Qubes OS dom0 (hyprliquid look)

The fuzzel launcher from [hyprliquid-dotfiles](https://github.com/1mirax/hyprliquid-dotfiles)
(`dots/.config/fuzzel`) as rofi in dom0: a 6% white veil over blurred
background, fuzzel's colours and padding, icons, a rounded selection.

Sizes are fuzzel's 1:1, measured off a screenshot of fuzzel running the
hyprliquid `fuzzel.ini`: a 746×454 window with a 3 px `#ffffff40` border and
42 px corners, 15 rows of 27 px, 22 px text, 20 px icons.

rofi draws the border and the rounded corners. **picom blurs what is behind
the window** — without picom the launcher is a flat dark box.

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
- **picom must round rofi with the same 42 px.** picom blurs the window's
  whole area. With a smaller radius (or none) the blur shows past rofi's round
  corners; with a larger one it cuts into the border. Check your version with
  `picom --version`, then add one of these:

  picom 12 and newer:

  ```
  rules = ( { match = "class_g = 'Rofi'"; corner-radius = 42; } );
  ```

  If your config has no `rules` yet, note that picom 12 ignores the old
  per-window options (`rounded-corners-exclude` and friends) once `rules`
  exists.

  picom 11:

  ```
  corner-radius-rules = [ "42:class_g = 'Rofi'" ];
  ```

## Security

- `drun-display-format` is `{name}` only. App names come from the qubes, and
  the default format wraps them in Pango markup.
- rofi runs the entry's `Exec` line in dom0. Qubes writes those lines itself
  (`qvm-run ... qubes.StartApp+...`); a qube can't change them.
