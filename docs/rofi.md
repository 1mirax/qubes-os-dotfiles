# rofi for Qubes OS dom0 (hyprliquid look)

The fuzzel launcher from [hyprliquid-dotfiles](https://github.com/1mirax/hyprliquid-dotfiles)
(`dots/.config/fuzzel`) as rofi in dom0: a 6% white veil over blurred
background, fuzzel's colours and padding, icons, a rounded selection.

It opens on a list of your qubes, each with its coloured cube icon. Pick
one and the same window lists that qube's apps under their plain names —
`Firefox`, not `work: Firefox`. `← qubes` at the end of the list goes back,
Esc closes. `dom0` at the end holds dom0's own tools.

Templates are left out of the qube list. To change what is hidden, edit
`HIDE_TYPES` and `HIDE_QUBES` at the top of `qubes-menu.py`.

`rofi -show drun` still works too, with every app at once.

Sizes are fuzzel's, in a 454 px square: 3 px `#ffffff40` border, 42 px
corners, 15 rows of 27 px, 22 px text, 20 px icons. The glass is dark —
`#14141a` at 50%, the terminal's and mako's colour. fuzzel's white 6% veil only
worked because Hyprland dimmed the desktop behind it; over a white window
here it left white text on white.

rofi draws the border and the corners. **picom blurs what is behind the
window**; without picom the launcher is a flat dark box.

## Install

1. In a qube with network, get the repository (or `git pull` it):

   ```bash
   git clone https://github.com/1mirax/qubes-os-dotfiles ~/qubes-os-dotfiles
   ```

2. In dom0, with `<qube>` being that qube:

   ```bash
   sudo qubes-dom0-update rofi
   mkdir -p ~/.config/rofi
   for f in config.rasi qubes-menu.py; do
       qvm-run --pass-io <qube> "cat /home/user/qubes-os-dotfiles/dom0/rofi/$f" > ~/.config/rofi/$f
   done
   chmod 755 ~/.config/rofi/qubes-menu.py
   less ~/.config/rofi/config.rasi ~/.config/rofi/qubes-menu.py
   ```

   Read both in dom0: `qubes-menu.py` runs there.

3. Try it from a dom0 terminal, then bind it in the i3 config in place of
   the default `$mod+d` line:

   ```
   bindsym $mod+d exec --no-startup-id rofi -show qubes -modi "qubes:$HOME/.config/rofi/qubes-menu.py"
   ```

The font, Inter Tab, comes from the polybar bundle. Without it rofi falls back
to the default sans font.

## picom

`dom0/picom/picom.conf` in this repository already has the rule below.

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

- App names come from the qubes. They reach rofi as plain text, with markup
  off, so a name can't restyle the list or fake another qube's colour.
- The qube list, the cube icons and the `dom0` group come from dom0
  (qubesadmin and dom0's own menu entries), never from a qube.
- An app is started with `gio launch` on its menu entry, which runs the
  entry's `Exec` line. Qubes writes that line itself
  (`qvm-run ... qubes.StartApp+...`); a qube can't change it.
