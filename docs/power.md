# Power: lid, idle lock, stay awake

| State | What happens |
|---|---|
| Lid closed | Full power off — the disk is encrypted again |
| Lid open, idle | The screen locks after a few minutes; no suspend |
| Stay awake on (bar, "zzz") | No blanking, no lock until switched off |

A forgotten stay-awake switch can't leave the laptop open: closing the lid
still powers it off.

## Lid: power off

In dom0:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
qvm-run --pass-io <qube> 'cat /home/user/qubes-os-dotfiles/dom0/power/lid-poweroff.conf' \
  | sudo tee /etc/systemd/logind.conf.d/lid-poweroff.conf >/dev/null
sudo systemctl kill -s HUP systemd-logind
```

Use `kill -s HUP`, not `restart`: restarting logind ends the session.

If `systemd-inhibit --list | grep -i lid` shows `handle-lid-switch`, another
program (usually `xfce4-power-manager`) takes the lid and logind never sees
it. Stop it and keep it from starting, the same way as `xfce4-notifyd` in
[dunst.md](dunst.md):

```bash
pkill xfce4-power-manager
printf '[Desktop Entry]\nHidden=true\n' > ~/.config/autostart/xfce4-power-manager.desktop
```

Closing the lid shuts every qube down; unsaved work in them is lost. To undo,
delete the file and send logind `HUP` again.

## Idle: lock, don't sleep

The lock comes from xscreensaver, as in Qubes' own Xfce session. Check that it
runs in the i3 session:

```bash
pgrep -a xscreensaver || echo 'exec --no-startup-id xscreensaver --no-splash' >> ~/.config/i3/config
```

Then set the times in `xscreensaver-settings`: **Blank after** 5 minutes,
**Lock screen after** 0 (lock as soon as it blanks). Nothing suspends on idle
as long as `xfce4-power-manager` isn't running and logind's `IdleAction` is
left at its default (`ignore`).

## Stay awake

The "zzz" button in the bar, left of the brightness icon. Grey: the screen
locks when idle. White and struck through: it doesn't. Click to switch.

Qubes can't keep dom0 awake on their own — a video playing in a qube won't —
so this is what keeps a film from locking halfway. A screen locked by hand
stays locked. `MAX_HOURS` at the top of `~/.config/polybar/scripts/idle.sh`
switches it off by itself after that many hours; 0, the default, never does.
