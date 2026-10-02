#!/bin/bash
# Install qubes-tray-bg in a TEMPLATE (run as root in the template, not dom0).
#
# Every qube based on this template then paints the background behind its
# tray icons black instead of the white that the Qubes GUI agent hard-codes.
# See the comment at the top of the helper below for the details.
#
# Changes: installs python3-xlib from the template's signed repository, and
# adds two files: /opt/qubes-tray-bg/qubes-tray-bg.py and
# /etc/xdg/autostart/qubes-tray-bg.desktop. Undo: delete both files.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo bash $0" >&2; exit 1
fi

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" fedora "*|*" rhel "*)   dnf install -y -q python3-xlib ;;
    *" debian "*|*" ubuntu "*) apt-get update -q && apt-get install -y -q python3-xlib ;;
    *) echo "Unsupported template: ${PRETTY_NAME:-unknown}" >&2; exit 1 ;;
esac

# /opt, not /usr/local: in app qubes /usr/local comes from the qube's own
# /rw, so the template's copy there would never be seen.
install -d -m 755 /opt/qubes-tray-bg
cat > /opt/qubes-tray-bg/qubes-tray-bg.py <<'EOF_HELPER'
#!/usr/bin/env python3
"""Dark background behind this qube's tray icons.

Runs INSIDE a qube (installed in its template), never in dom0.

Why the icons are white: the Qubes GUI agent docks every tray icon into a
small "embedder" window, and creates that window with a hard-coded white
background (qubes-gui-agent-linux, gui-agent/vmside.c:
XCreateSimpleWindow(..., WhitePixel(...))). Most tray icons have no
background of their own and show whatever is behind them - that white
window. dom0 only ever receives the finished picture, so nothing in dom0 or
in the bar can take the white out again.

What this does: it watches this qube's own X server, and whenever the agent
docks an icon, it changes that embedder's background to BACKGROUND and asks
the icon to redraw. Nothing else is touched: a window only counts as an
embedder if it sits directly on the root window and holds exactly one child
that declares itself a tray icon (_XEMBED_INFO).

Event driven: it sleeps until the X server reports a change.
"""
import sys
import time

from Xlib import X, display, error

# Your bar's background. Change it here if the bar colour ever changes.
BACKGROUND = 0x000000


def main():
    while True:
        try:
            run(display.Display())
        except (error.ConnectionClosedError, error.DisplayError, OSError):
            time.sleep(2)           # X restarting - try again


def run(d):
    root = d.screen().root
    xembed_info = d.intern_atom("_XEMBED_INFO")

    def is_icon(win):
        try:
            return win.get_full_property(xembed_info, X.AnyPropertyType) is not None
        except error.XError:
            return False

    def paint(embedder, icon):
        # These requests don't wait for a reply, so a vanished window is
        # reported later, not raised here. CatchError swallows exactly that
        # instead of printing it to the session log.
        gone = error.CatchError(error.BadWindow)
        embedder.change_attributes(onerror=gone, background_pixel=BACKGROUND)
        embedder.clear_area(onerror=gone)
        # exposures=True makes the icon redraw itself on the new colour
        icon.clear_area(exposures=True, onerror=gone)
        d.flush()

    def check(win):
        """If win is an embedder holding a tray icon, paint it."""
        try:
            tree = win.query_tree()
        except error.XError:
            return
        if tree.parent != root or len(tree.children) != 1:
            return
        icon = tree.children[0]
        if is_icon(icon):
            paint(win, icon)

    # Icons docked before we started.
    for win in root.query_tree().children:
        check(win)

    # The agent reparents each new icon into its embedder; the root window
    # reports that as a ReparentNotify.
    root.change_attributes(event_mask=X.SubstructureNotifyMask)
    d.flush()
    while True:
        ev = d.next_event()
        if ev.type == X.ReparentNotify and ev.parent != root:
            check(ev.parent)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
EOF_HELPER
chmod 755 /opt/qubes-tray-bg/qubes-tray-bg.py

install -d -m 755 /etc/xdg/autostart
cat > /etc/xdg/autostart/qubes-tray-bg.desktop <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=Dark tray icon background (Qubes)
Exec=/opt/qubes-tray-bg/qubes-tray-bg.py
OnlyShowIn=X-QUBES;
NoDisplay=true
EOF_DESKTOP

echo "Installed. Shut down this template, then restart the qubes based on it."
