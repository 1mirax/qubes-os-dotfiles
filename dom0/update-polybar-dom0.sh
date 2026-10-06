#!/bin/bash
# Update an installed hyprliquid polybar in dom0 - config and scripts only.
# Fonts and the i3 config are not touched. The current ~/.config/polybar is
# kept as ~/.config/polybar.bak-<date> first.
#
# Run in dom0, after reading it. It needs no network and no root.
set -euo pipefail

dest=~/.config/polybar
if [ ! -d "$dest" ]; then
    echo "No $dest - run the full build/install first." >&2
    exit 1
fi
stamp=$(date +%Y%m%d-%H%M%S)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
mkdir -p "$OUT/polybar/scripts"

echo "==> Writing polybar config"
cat > "$OUT/polybar/config.ini" <<'EOF_CONFIG'
; polybar for Qubes OS dom0 + i3 - the hyprliquid waybar, rebuilt for X11.
;
; Same layout as dots/.config/waybar: logo and focused window on the left,
; readings | workspace pill | clock in the centre, status on the right.
; Network and bluetooth are gone on purpose: they live in sys-net, and their
; applets appear in the tray framed in the qube's colour.
;
; polybar does not expand ${colors.x} inside %{...} tags, so colours in tags
; are literals. Change one here, then search for its hex.

[colors]
foreground = #e8e8ec
muted      = #b9b9c1
faint      = #8b8b93
background = #000000
; waybar's alpha() colours, pre-mixed over black:
;   alpha(fg, 0.105) = pill  alpha(fg, 0.92) = active   alpha(fg, 0.14) = rule
pill       = #18181a
active     = #d5d5d9
rule       = #202021
warning    = #c3a56d
critical   = #c26873

[settings]
screenchange-reload = true

[bar/main]
width  = 100%
; 28 px drawing area plus 5 px black border above and below = waybar's 38.
; The pill has to fill the drawing area edge to edge, hence the border.
height = 28
border-top-size    = 5
border-bottom-size = 5
border-color       = #000000
background = #000000
foreground = #b9b9c1
; overline/underline that insets the active workspace (see workspaces.py)
line-size = 4
padding-left  = 10px
padding-right = 14px

; polybar multiplies pixelsize by dpi/72 (measured, despite its docs).
; Pinning 72 makes pixelsize mean real pixels, like waybar's px.
dpi = 72

; Fonts are %{T1}..%{T10}. The number after ";" moves that font down by
; that many pixels - the knob to turn if something sits too high or low.
; T1  text, window title, readings
font-0 = Inter Tab:pixelsize=16;3
; T2  big icons: logo, volume, brightness
font-1 = Symbols Nerd Font:pixelsize=22;2
; T3  outer pill ends (28 px tall)
font-2 = Symbols Nerd Font:pixelsize=28;4
; T4  active pill ends (20 px tall)
font-3 = Symbols Nerd Font:pixelsize=20;3
; T5  qube name
font-4 = Inter Tab:weight=semibold:pixelsize=16;3
; T6  workspace digits
font-5 = Inter Tab:weight=semibold:pixelsize=15;3
; T7  clock
font-6 = Inter Tab:weight=semibold:pixelsize=17;3
; T8  battery
font-7 = Inter Tab:pixelsize=15;3
; T9  small icons in the readings
font-8 = Symbols Nerd Font:pixelsize=16;2
; T10 group separators
font-9 = Inter Tab:pixelsize=13;2

modules-left   = launcher window
modules-center = stats workspaces clock balance
; launch.sh drops "backlight" when the machine has no backlight device
modules-right  = ${env:POLYBAR_RIGHT:tray sep backlight pulseaudio sep battery}
fixed-center = true

; A normal dock window: i3 reserves the space, nothing is drawn over apps.
override-redirect = false
enable-ipc = true
cursor-click = pointer

; ---------------------------------------------------------------- left ---

[module/launcher]
type = custom/text
; The Qubes logo (Nerd Fonts U+F342). Opens the Qubes app menu with its
; Apps / Templates / Service qubes tabs.
format = %{O8}%{T2}@QUBES@%{T-}%{O12}
format-foreground = #e8e8ec
click-left = qubes-app-menu &

[module/window]
type = custom/script
exec = ~/.config/polybar/scripts/qube-window.sh
tail = true
; the 1 px rule between the logo and the title
format = %{B#202021}%{O1}%{B-}%{O14}<label>%{O14}
label = %output%

; -------------------------------------------------------------- centre ---

[module/stats]
type = custom/script
exec = ~/.config/polybar/scripts/qubes-stats.sh
tail = true
format = <label>%{O10}
label = %output%
; xentop is the btop of Qubes: every qube, not just dom0. xterm in case
; Xfce was removed from dom0. Not i3-sensible-terminal: on Qubes that opens
; a terminal in the focused qube.
click-left = (xfce4-terminal --title=xentop -x sudo xentop || xterm -T xentop -e sudo xentop) &

[module/workspaces]
type = custom/script
exec = ~/.config/polybar/scripts/workspaces.py
tail = true
label = %output%

[module/clock]
type = internal/date
interval = 1
; Fixed length, as in waybar: %d pads to two digits, %b is three letters.
; Click for the long form.
date = %H:%M  ·  %d %b
date-alt = %A, %d %B
; English names keep %b at three letters whatever the system locale is
locale = en_US.UTF-8
label = %{T7}%date%%{T-}
format-prefix = %{O8}

; Invisible counterweight, as in waybar: polybar centres the whole centre
; group, so the width left of the pill must be matched on its right.
; Measured: 121 centres the pill exactly. If it ever sits X px LEFT of the
; screen centre, make this 2*X smaller; X px RIGHT, make it 2*X bigger.
[module/balance]
type = custom/text
format = %{O121}

; --------------------------------------------------------------- right ---

; Qubes widgets (domains, devices, updates, disk) and every qube's applets.
[module/tray]
type = internal/tray
tray-size = 20px
tray-spacing = 10px
format-prefix = %{O10}
format-suffix = %{O6}

[module/sep]
type = custom/text
format = %{T10}|%{T-}
format-foreground = #8b8b93
format-padding = 2px

[module/backlight]
type = internal/backlight
; picked by launch.sh from /sys/class/backlight (intel_backlight on the X390)
card = ${env:POLYBAR_BACKLIGHT:intel_backlight}
use-actual-brightness = true
enable-scroll = false
; scroll to change, click for full - through brightnessctl, which asks
; systemd-logind instead of needing write access to /sys. Actions run in a
; shell that inherits POLYBAR_BACKLIGHT from launch.sh. (polybar expands
; ${env:...} only when it is the whole value, so it can't be used here.)
format = %{O9}%{A4:brightnessctl -q -d "$POLYBAR_BACKLIGHT" set 5%+:}%{A5:brightnessctl -q -d "$POLYBAR_BACKLIGHT" set 5%-:}%{A1:brightnessctl -q -d "$POLYBAR_BACKLIGHT" set 100%:}<ramp>%{A}%{A}%{A}%{O9}
ramp-0 = %{T2}@SUN0@%{T-}
ramp-1 = %{T2}@SUN1@%{T-}
ramp-2 = %{T2}@SUN2@%{T-}

[module/pulseaudio]
type = internal/pulseaudio
; up to 150%, as in waybar; scroll and click-to-mute are built in
use-ui-max = true
interval = 5
format-volume = %{O9}<ramp-volume>%{O9}
format-muted  = %{O9}<label-muted>%{O9}
label-muted = %{T2}@VOLMUTE@%{T-}
label-muted-foreground = #8b8b93
ramp-volume-0 = %{T2}@VOL0@%{T-}
ramp-volume-1 = %{T2}@VOL1@%{T-}
ramp-volume-2 = %{T2}@VOL2@%{T-}
click-right = pavucontrol &

[module/battery]
type = custom/script
; first BAT* in /sys/class/power_supply; give BAT1 etc. to pick another
exec = ~/.config/polybar/scripts/battery.sh
interval = 5
label = %{T8}%output%%{T-}
format-prefix = %{O5}
EOF_CONFIG

# Icons as UTF-8 bytes, so no glyph can get lost while copying this file.
sed -i \
    -e "s/@QUBES@/$(printf '\xef\x8d\x82')/g" \
    -e "s/@SUN0@/$(printf '\xf3\xb0\x83\x9e')/g" \
    -e "s/@SUN1@/$(printf '\xf3\xb0\x83\x9f')/g" \
    -e "s/@SUN2@/$(printf '\xf3\xb0\x83\xa0')/g" \
    -e "s/@VOL0@/$(printf '\xf3\xb0\x95\xbf')/g" \
    -e "s/@VOL1@/$(printf '\xf3\xb0\x96\x80')/g" \
    -e "s/@VOL2@/$(printf '\xf3\xb0\x95\xbe')/g" \
    -e "s/@VOLMUTE@/$(printf '\xf3\xb0\x96\x81')/g" \
    "$OUT/polybar/config.ini"

# ---------------------------------------------------------------------------
cat > "$OUT/polybar/launch.sh" <<'EOF_LAUNCH'
#!/bin/bash
# Start polybar, replacing a running one. i3 runs this at login and on
# every reload (exec_always in ~/.config/i3/config).
set -u

# Backlight device, the way desktops pick it: firmware, then platform, then
# raw. Without one (a desktop machine) the module is left out.
card=""
for type in firmware platform raw; do
    for d in /sys/class/backlight/*; do
        { read -r t < "$d/type"; } 2>/dev/null || continue
        [ "$t" = "$type" ] && { card=${d##*/}; break 2; }
    done
done
if [ -n "$card" ]; then
    export POLYBAR_BACKLIGHT=$card
    export POLYBAR_RIGHT="tray sep backlight pulseaudio sep battery"
else
    export POLYBAR_RIGHT="tray sep pulseaudio sep battery"
fi

pkill -u "$(id -u)" -x polybar
for _ in $(seq 50); do
    pgrep -u "$(id -u)" -x polybar >/dev/null || break
    sleep 0.1
done
setsid polybar main >"${XDG_RUNTIME_DIR:-/tmp}/polybar.log" 2>&1 </dev/null &
EOF_LAUNCH

# ---------------------------------------------------------------------------
cat > "$OUT/polybar/scripts/qube-window.sh" <<'EOF_WINDOW'
#!/bin/bash
# Focused window: the qube it belongs to, in its label colour, then the name
# of the program - "Firefox", not the page title.
#
# The program name comes from WM_CLASS ("work:firefox" - the GUI daemon puts
# the qube name in front), never from the title. A title carries page names,
# file names and whatever else the program is showing, which is not something
# to keep on screen; it is also free text in any script, while a class is a
# short ASCII word.
#
# Event driven, nothing polls. One xprop follows _NET_ACTIVE_WINDOW on the
# root window; a second follows the focused window itself.
#
# SECURITY. The qube name and colour come from _QUBES_VMNAME and
# _QUBES_LABEL_COLOR, which dom0's GUI daemon sets - a qube cannot change
# them. WM_CLASS is set by the qube and is untrusted: polybar obeys "%{...}"
# tags anywhere in the text it draws, and %{A1:cmd:} would run cmd in dom0
# on a click. Only [A-Za-z0-9 ._-] of it is ever printed, so no tag can
# form.
set -u
set -m                      # every follower gets its own process group
export LC_ALL=C.UTF-8

MAX_NAME=32
DOM0_COLOR="#e8e8ec"        # dom0 and black-labelled qubes (black is invisible here)
NAME_COLOR="#b9b9c1"

follower=""
stop_follower() {
    # the whole group: the subshell, its xprop and its awk
    [ -n "$follower" ] && kill -- "-$follower" 2>/dev/null
    follower=""
}
trap 'stop_follower; exit 0' INT TERM HUP

follow() {
    xprop -notype -spy -id "$1" \
          _QUBES_VMNAME _QUBES_LABEL_COLOR WM_CLASS 2>/dev/null |
    awk -v max="$MAX_NAME" -v dom0="$DOM0_COLOR" -v ncol="$NAME_COLOR" '
        BEGIN {
            # Classes whose own name reads badly. Keys are lower case.
            nice["firefox"] = "Mozilla Firefox";  nice["firefox-esr"] = "Mozilla Firefox"
            nice["navigator"] = "Mozilla Firefox";  nice["tor browser"] = "Tor Browser"
            nice["xfce4-terminal"] = "Terminal";  nice["gnome-terminal-server"] = "Terminal"
            nice["qterminal"] = "Terminal";       nice["konsole"] = "Terminal"
            nice["org.gnome.nautilus"] = "Files"; nice["thunar"] = "Files"
            nice["pcmanfm-qt"] = "Files";         nice["nemo"] = "Files"
            nice["keepassxc"] = "KeePassXC";      nice["thunderbird"] = "Thunderbird"
            nice["code"] = "VS Code";             nice["chromium-browser"] = "Chromium"
            nice["google-chrome"] = "Chrome";     nice["signal"] = "Signal"
            nice["telegramdesktop"] = "Telegram"; nice["evince"] = "Documents"
            nice["libreoffice"] = "LibreOffice"
        }
        # "PROP = value" when set, "PROP:  not found." when not.
        /^_QUBES_VMNAME = /      { name = $0; sub(/^[^"]*"/, "", name); sub(/"$/, "", name) }
        /^_QUBES_VMNAME:/        { name = "" }
        /^_QUBES_LABEL_COLOR = / { color = $3 + 0 }
        /^_QUBES_LABEL_COLOR:/   { color = -1 }
        # WM_CLASS = "instance", "class" - the class is the last string
        /^WM_CLASS = /           { cls = $0; sub(/^.*, "/, "", cls); sub(/"$/, "", cls) }
        /^WM_CLASS:/             { cls = "" }
        { split($0, f, /[ :]/); seen[f[1]] = 1 }
        {
            if (length(seen) < 3) next      # wait for the first full set

            c = cls
            # Drop the "qube:" prefix the GUI daemon adds, only when it is
            # the real qube name.
            if (name != "" && index(c, name ":") == 1)
                c = substr(c, length(name) + 2)
            k = tolower(c)
            if (k in nice) c = nice[k]
            else if (k ~ /^libreoffice/) c = "LibreOffice"
            else {
                gsub(/[^A-Za-z0-9 ._-]/, "", c)
                c = toupper(substr(c, 1, 1)) substr(c, 2)
            }
            if (length(c) > max) c = substr(c, 1, max)

            if (name == "") { label = "dom0"; col = dom0 }
            else {
                label = name
                col = (color <= 0) ? dom0 : sprintf("#%06x", color)
            }
            # Qube names may only contain [A-Za-z0-9_.-], no tags possible.
            out = "%{F" col "}%{T5}" label "%{T-}%{F-}"
            if (c != "") out = out "%{O10}%{F" ncol "}" c "%{F-}"
            print out
            fflush()
        }'
}

while read -r _ _ _ _ id _; do
    id=${id%,}
    stop_follower
    if [ -z "$id" ] || [ "$id" = "0x0" ]; then
        echo ""             # nothing focused (empty workspace): module hides
        continue
    fi
    follow "$id" &
    follower=$!
done < <(xprop -notype -spy -root _NET_ACTIVE_WINDOW 2>/dev/null)

stop_follower
EOF_WINDOW

# ---------------------------------------------------------------------------
cat > "$OUT/polybar/scripts/qubes-stats.sh" <<'EOF_STATS'
#!/bin/bash
# Running qubes, CPU, RAM and temperature, in one line.
#
# dom0 is a virtual machine too: its /proc/stat and /proc/meminfo describe
# only dom0. xentop asks Xen and sees every qube at once.
#
# One process for everything: xentop -b keeps running and prints a fresh
# table every INTERVAL seconds, awk reads it as a stream. No fork and no
# sudo per update (sudo logs every call) - one sudo at login, that is all.
# xentop needs root; dom0's user already has passwordless sudo, and -n makes
# it fail instead of hanging if that ever changes.
set -u

INTERVAL=2
CRIT_TEMP=90
TEMP_FILE=""                    # empty = find it; or set a path by hand
FS=$'\xe2\x80\x87'              # figure space: as wide as a digit in Inter Tab
ICON_QUBES=$'\xf3\xb0\x86\xa7'  # cube outline
ICON_CPU=$'\xf3\xb0\xbb\xa0'
ICON_MEM=$'\xf3\xb0\x8d\x9b'
ICON_TEMP=$'\xf3\xb0\x94\x8f'

# Physical CPUs Xen schedules on. CPU(%) is per CPU (two busy cores = 200).
ncpu=$(sudo -n xl info 2>/dev/null | awk '$1 == "nr_cpus" { print $3 }')
[ -n "$ncpu" ] && [ "$ncpu" -gt 0 ] 2>/dev/null || ncpu=1

# Best sensor this laptop offers: Intel package, AMD package, the ThinkPad
# embedded controller (works even where Xen hides CPU sensors), ACPI zone.
find_temp() {
    local d z name want
    for want in coretemp k10temp thinkpad; do
        for d in /sys/class/hwmon/hwmon*; do
            { read -r name < "$d/name"; } 2>/dev/null || continue
            [ "$name" = "$want" ] && [ -r "$d/temp1_input" ] && { echo "$d/temp1_input"; return; }
        done
    done
    for want in x86_pkg_temp acpitz; do
        for z in /sys/class/thermal/thermal_zone*; do
            { read -r name < "$z/type"; } 2>/dev/null || continue
            [ "$name" = "$want" ] && [ -r "$z/temp" ] && { echo "$z/temp"; return; }
        done
    done
}
[ -n "$TEMP_FILE" ] || TEMP_FILE=$(find_temp)

# stdbuf: otherwise xentop's output waits in a 4 KiB pipe buffer.
sudo -n stdbuf -oL xentop -b -d "$INTERVAL" 2>/dev/null |
awk -v ncpu="$ncpu" -v tfile="$TEMP_FILE" -v crit="$CRIT_TEMP" -v fs="$FS" \
    -v iq="$ICON_QUBES" -v icpu="$ICON_CPU" -v imem="$ICON_MEM" -v itemp="$ICON_TEMP" '
    # Fixed width for the whole group, not per reading: every value missing
    # a digit adds one blank (U+2007, exactly one digit wide in Inter Tab) to
    # a single block IN FRONT of the first icon. Gaps between readings stay
    # equal; the spare space sits at the far left, next to empty bar, and the
    # pill never moves. Counts digits, not bytes (fs is three bytes).
    function blanks(k,   s) { s = ""; while (k-- > 0) s = s fs; return s }
    function icon(g) { return "%{T9}" g "%{T-}%{O5}" }
    # Empty values give the same width, so the placeholder printed at
    # start-up holds exactly the space of real data.
    function line(n, cpu, mem, t,   miss, hot, out) {
        miss = (2 - length(n "")) + (3 - length(cpu "")) + (3 - length(mem ""))
        out = icon(iq) n "%{O10}" icon(icpu) cpu "%" "%{O10}" icon(imem) mem "%"
        if (tfile != "") {
            miss += 3 - length(t "")
            hot = (t != "" && t >= crit)
            out = out "%{O10}" (hot ? "%{F#c26873}" : "") icon(itemp) t "°" (hot ? "%{F-}" : "")
        }
        return blanks(miss) out
    }
    function report(   i, n, base, cpu, mem, t) {
        # Running qubes: not dom0, not paused/dying/shut down/crashed
        # (preloaded disposables wait paused), and not the "-dm" stub
        # domains that emulate hardware for sys-net, sys-usb and other HVMs.
        n = 0
        for (i = 1; i <= rows; i++) {
            if (name[i] == "Domain-0") continue
            if (state[i] ~ /[pdsc]/) continue
            if (name[i] ~ /-dm$/) {
                base = substr(name[i], 1, length(name[i]) - 3)
                if (base in present) continue
            }
            n++
        }
        cpu = int(cpu_sum / ncpu + 0.5); if (cpu > 100) cpu = 100
        mem = int(mem_sum + 0.5);        if (mem > 100) mem = 100
        t = ""
        if (tfile != "" && (getline t < tfile) > 0) t = int(t / 1000 + 0.5)
        close(tfile)
        print line(n, cpu, mem, t)
        fflush()
    }
    # xentop needs two samples before it knows CPU usage: hold the space.
    BEGIN { print line("", "", "", ""); fflush() }
    # Every table starts with its header; the next header closes the last one.
    $1 == "NAME" {
        if (rows) report()
        rows = 0; cpu_sum = 0; mem_sum = 0
        delete present
        next
    }
    # A domain row: name, then a six-letter state such as "--b---".
    $2 ~ /^[-a-z][-a-z][-a-z][-a-z][-a-z][-a-z]$/ {
        rows++
        name[rows] = $1; state[rows] = $2; present[$1] = 1
        cpu_sum += $4           # CPU(%)
        mem_sum += $6           # MEM(%): share of all physical RAM
    }'
EOF_STATS

# ---------------------------------------------------------------------------
cat > "$OUT/polybar/scripts/workspaces.py" <<'EOF_WS'
#!/usr/bin/env python3
"""i3 workspace pill for polybar.

Workspaces 1-5 are always shown, as in the waybar version: empty ones dim,
occupied ones brighter, the focused one as a bright pill. Any other numbered
workspace that exists (6, 7, ...) is added after them.

polybar's own internal/i3 module only lists workspaces that exist, hence this
script. It talks to i3's IPC socket directly - Python standard library only,
nothing to install in dom0 - and sleeps until i3 reports a change.

Only the workspace NUMBER (an int from i3) is ever printed or put into a
click command, never a name, so nothing here can inject polybar tags.
"""
import json
import os
import socket
import struct
import subprocess
import sys
import time

ALWAYS = range(1, 6)

PILL, ACTIVE, ACTIVE_FG = "#18181a", "#d5d5d9", "#14141a"
MUTED, FAINT, CRITICAL = "#b9b9c1", "#8b8b93", "#c26873"
CAP_L, CAP_R = "\ue0b6", "\ue0b4"   # half circles, the rounded pill ends
# Side padding of an inactive button. Must equal an active pill's end cap
# plus its inner padding, or the pill changes width when you switch.
PAD = 12

MAGIC = b"i3-ipc"
HEADER = struct.Struct("=6sII")
GET_WORKSPACES, SUBSCRIBE = 1, 2


def socket_path():
    path = os.environ.get("I3SOCK")
    if not path:
        path = subprocess.run(["i3", "--get-socketpath"], capture_output=True,
                              text=True, check=True).stdout.strip()
    return path


def connect(path):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(path)
    return s


def send(s, kind, payload=b""):
    s.sendall(HEADER.pack(MAGIC, len(payload), kind) + payload)


def recv_exact(s, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("i3 closed the socket")
        buf += chunk
    return bytes(buf)


def recv(s):
    magic, length, kind = HEADER.unpack(recv_exact(s, HEADER.size))
    if magic != MAGIC:
        raise ConnectionError("not an i3 reply")
    return kind, json.loads(recv_exact(s, length))


def button(n, state):
    click = f"%{{A1:i3-msg -q workspace number {int(n)}:}}"
    if state == "active":
        # Bright band: 28 px of background with a 4 px overline and underline
        # in the pill colour painted over it, which leaves 20 px between the
        # 20 px end caps.
        body = (f"%{{F{ACTIVE}}}%{{T4}}{CAP_L}%{{T-}}"
                f"%{{B{ACTIVE}}}%{{o{PILL}}}%{{u{PILL}}}%{{+o}}%{{+u}}"
                f"%{{F{ACTIVE_FG}}}%{{T6}}%{{O1}}{n}%{{O1}}%{{T-}}"
                f"%{{-o}}%{{-u}}%{{B{PILL}}}"
                f"%{{F{ACTIVE}}}%{{T4}}{CAP_R}%{{T-}}%{{F-}}")
    else:
        color = {"urgent": CRITICAL, "occupied": MUTED}.get(state, FAINT)
        body = f"%{{F{color}}}%{{T6}}%{{O{PAD}}}{n}%{{O{PAD}}}%{{T-}}%{{F-}}"
    return f"%{{O2}}{click}{body}%{{A}}%{{O2}}"


def emit(line):
    # A broken stdout means polybar is gone - so are we. Kept apart from the
    # i3 sockets, where a broken pipe only means i3 restarted.
    try:
        print(line, flush=True)
    except BrokenPipeError:
        sys.exit(0)


def render(query):
    send(query, GET_WORKSPACES)
    _, workspaces = recv(query)
    state = {}
    for ws in workspaces:
        n = ws.get("num", -1)
        if not isinstance(n, int) or n < 1:
            continue                        # workspaces without a number
        if ws.get("focused"):
            state[n] = "active"
        elif ws.get("urgent"):
            state[n] = "urgent"
        else:
            state[n] = "occupied"           # i3 deletes empty unfocused ones
    buttons = "".join(button(n, state.get(n, "empty"))
                      for n in sorted(set(ALWAYS) | set(state)))
    # The round ends already give the buttons room: no extra padding inside.
    emit(f"%{{F{PILL}}}%{{T3}}{CAP_L}%{{T-}}%{{F-}}%{{B{PILL}}}"
         f"{buttons}"
         f"%{{B-}}%{{F{PILL}}}%{{T3}}{CAP_R}%{{T-}}%{{F-}}")


def main():
    while True:
        socks = []
        try:
            path = socket_path()
            events, query = connect(path), connect(path)
            socks = [events, query]
            send(events, SUBSCRIBE, b'["workspace", "output"]')
            recv(events)                    # {"success": true}
            render(query)
            while True:
                recv(events)                # what changed does not matter
                render(query)
        except (OSError, ConnectionError, ValueError,
                subprocess.CalledProcessError):
            time.sleep(1)                   # i3 restarting: reconnect
        finally:
            for s in socks:
                s.close()


if __name__ == "__main__":
    main()
EOF_WS

# ---------------------------------------------------------------------------
cat > "$OUT/polybar/scripts/battery.sh" <<'EOF_BAT'
#!/bin/bash
# Battery, same reading as waybar: "84% ↓7W". Argument: BAT0, BAT1 ...
# (default: the first one there is). Natural width, flush with the screen edge.
set -u

if [ -n "${1:-}" ]; then
    BAT=/sys/class/power_supply/$1
else
    BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
fi
WARN=20
CRIT=10

{ read -r cap < "$BAT/capacity"; } 2>/dev/null || { echo ""; exit 0; }
{ read -r status < "$BAT/status"; } 2>/dev/null || status=Unknown

# power_now in microwatts; some batteries give current and voltage instead
if { read -r p < "$BAT/power_now"; } 2>/dev/null; then
    watts=$(( (p + 500000) / 1000000 ))
elif { read -r i < "$BAT/current_now" && read -r v < "$BAT/voltage_now"; } 2>/dev/null; then
    watts=$(( (i / 1000 * (v / 1000) + 500000) / 1000000 ))
else
    watts=0
fi

case "$status" in
    Discharging) tail="↓${watts}W" ;;
    Charging)    tail="↑${watts}W" ;;
    *)           tail="AC" ;;       # plugged in, holding at a charge limit
esac

# No padding: the battery sits flush at the right edge. When a number gains
# or loses a digit (9W -> 10W) the icons to its left move by one digit.
text="$cap% $tail"

if [ "$status" != Charging ] && [ "$cap" -le "$CRIT" ]; then
    echo "%{F#c26873}$text%{F-}"
elif [ "$cap" -le "$WARN" ]; then
    echo "%{F#c3a56d}$text%{F-}"
else
    echo "$text"
fi
EOF_BAT


chmod 755 "$OUT/polybar/launch.sh" "$OUT/polybar/scripts/"*

cp -a "$dest" "$dest.bak-$stamp"
echo "==> Old config kept in $dest.bak-$stamp"
cp "$OUT/polybar/config.ini" "$OUT/polybar/launch.sh" "$dest/"
mkdir -p "$dest/scripts"
cp "$OUT/polybar/scripts/"* "$dest/scripts/"

echo "==> Restarting polybar"
"$dest/launch.sh"
echo "Done. To go back: rm -r $dest && mv $dest.bak-$stamp $dest && $dest/launch.sh"
