# dunst for Qubes OS dom0 (hyprliquid look)

The mako notifications from [hyprliquid-dotfiles](https://github.com/1mirax/hyprliquid-dotfiles)
(`dots/.config/mako`) as dunst in dom0, smaller: 380 px wide, top right under
the bar, at most three at a time plus a "(N more)" line, 2 px border, 18 px
corners, the terminal's dark glass at 40% blurred by picom. No
notification centre, no modes, no history.

Notifications from qubes are forwarded to dom0 and shown by dunst too.

## Install

1. In dom0, with `<qube>` holding this repository:

   ```bash
   sudo qubes-dom0-update dunst
   mkdir -p ~/.config/dunst
   qvm-run --pass-io <qube> 'cat /home/user/qubes-os-dotfiles/dom0/dunst/dunstrc' > ~/.config/dunst/dunstrc
   less ~/.config/dunst/dunstrc
   ```

2. Start it from the i3 config, near the top:

   ```
   exec --no-startup-id dunst
   ```

   Only one program can show notifications, and `xfce4-notifyd` usually
   gets there first at login. Keep it from starting, for your user only:

   ```bash
   systemctl --user mask xfce4-notifyd.service
   mkdir -p ~/.config/autostart ~/.local/share/dbus-1/services
   printf '[Desktop Entry]\nHidden=true\n' > ~/.config/autostart/xfce4-notifyd.desktop
   printf '[D-BUS Service]\nName=org.freedesktop.Notifications\nExec=/usr/bin/dunst\n' \
     > ~/.local/share/dbus-1/services/org.freedesktop.Notifications.service
   ```

   The last file makes the first notification start dunst if it isn't
   running. Log out and back in (or reboot). To undo, `systemctl --user
   unmask xfce4-notifyd.service` and delete the two files.

3. Test: `notify-send "Hello" "from dom0"`.

The font, Inter Tab, comes from the polybar bundle.

## picom

`dom0/picom/picom.conf` in this repository already has the rule below.

dunst draws its own 18 px corners and border; picom should round the dunst
window with the same 18 px, like rofi's 42:

```
rules = ( { match = "class_g = 'Dunst'"; corner-radius = 18; } );   # picom 12+
corner-radius-rules = [ "18:class_g = 'Dunst'" ];                   # picom 11
```

If picom's global `corner-radius` is already 18, nothing to add.

Notifications stack as one sheet of glass with a thin rule between them,
not as separate cards: picom blurs the whole dunst window, so gaps between
cards would show blurred background.

## Security

- `markup = no`: a notification's text is shown as plain text. A qube can't
  restyle it — colour it red, make it huge — to look like a dom0 message.
  The bold title comes from dunst's own format, around the escaped text.
