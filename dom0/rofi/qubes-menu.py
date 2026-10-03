#!/usr/bin/env python3
"""Two-step launcher for rofi in dom0: pick a qube, then one of its apps.

    rofi -show qubes -modi "qubes:$HOME/.config/rofi/qubes-menu.py"

The first list is every qube that has menu entries, with its own coloured
cube icon. Choosing one lists that qube's apps under their plain names - the
"work: " prefix the menu entries carry is dropped, the prompt already says
which qube it is. "dom0" at the end holds dom0's own tools.

This is a rofi script mode: rofi runs the script again for every choice and
shows what it prints. Python standard library plus qubesadmin, which dom0
already has.

Nothing a qube writes is trusted here. App names reach rofi as plain text
(markup stays off), and the qube list, its icons and the dom0 group come from
dom0: qubesadmin and dom0's own menu entries. Apps are started with
`gio launch`, which runs the entry's Exec line - written by Qubes itself
(qvm-run ... qubes.StartApp+...), not by the qube.
"""
import configparser
import os
import subprocess
import sys

APPS_HOME = os.path.expanduser("~/.local/share/applications")
DATA_DIRS = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
DESKTOPS = set(filter(None, os.environ.get("XDG_CURRENT_DESKTOP", "").split(":")))

# App qubes and disposables first, templates and the rest after, dom0 last.
ORDER = {"AppVM": 0, "DispVM": 0, "StandaloneVM": 1, "TemplateVM": 2}
ICON_PREFIX = {"AppVM": "appvm", "DispVM": "dispvm", "StandaloneVM": "standalonevm",
               "TemplateVM": "templatevm", "AdminVM": "adminvm"}
BACK = "←  qubes"


def entries():
    """Every visible menu entry as (qube or None, name, icon, path).

    A desktop file id in ~/.local/share/applications hides one of the same
    name further down the search path, as the XDG spec says.
    """
    seen = set()
    dirs = [APPS_HOME] + [os.path.join(d, "applications")
                          for d in DATA_DIRS.split(":") if d]
    for base in dirs:
        for root, _, files in os.walk(base):
            for fn in sorted(files):
                if not fn.endswith(".desktop"):
                    continue
                path = os.path.join(root, fn)
                did = os.path.relpath(path, base).replace(os.sep, "-")
                if did in seen:
                    continue
                seen.add(did)
                e = read(path)
                if e:
                    yield e


def read(path):
    p = configparser.ConfigParser(interpolation=None, strict=False)
    p.optionxform = str
    try:
        p.read(path, encoding="utf-8")
        d = p["Desktop Entry"]
    except (configparser.Error, KeyError, UnicodeDecodeError, OSError):
        return None
    if d.get("Type") != "Application" or "Name" not in d:
        return None
    if d.get("NoDisplay") == "true" or d.get("Hidden") == "true":
        return None
    only = set(filter(None, d.get("OnlyShowIn", "").split(";")))
    nope = set(filter(None, d.get("NotShowIn", "").split(";")))
    if (only and not only & DESKTOPS) or nope & DESKTOPS:
        return None
    qube = d.get("X-Qubes-VmName") or None
    name = " ".join(d["Name"].split())          # no newlines or tabs
    if qube and name.startswith(qube + ": "):
        name = name[len(qube) + 2:]
    return qube, name, d.get("Icon", ""), path


def qube_info():
    """{name: (class, icon)} for every qube, from dom0."""
    import qubesadmin
    app = qubesadmin.Qubes()
    info = {}
    for vm in app.domains:
        klass = vm.klass
        try:
            icon = vm.icon
        except Exception:
            icon = "%s-%s" % (ICON_PREFIX.get(klass, "appvm"), vm.label.name)
        info[vm.name] = (klass, icon)
    return info


def row(text, icon="", info=""):
    opts = []
    if icon:
        opts.append("icon\x1f" + icon)
    if info:
        opts.append("info\x1f" + info)
    # \0 and \x1f are rofi's separators; a name must not carry them
    text = text.replace("\0", "").replace("\x1f", "")
    print(text + ("\0" + "\x1f".join(opts) if opts else ""))


def mode(prompt):
    print("\0prompt\x1f" + prompt)
    print("\0no-custom\x1ftrue")


def list_qubes():
    apps = {}
    for qube, *_ in entries():
        apps[qube or "dom0"] = True
    info = qube_info()
    names = [q for q in apps if q in info]
    names.sort(key=lambda q: (q == "dom0", ORDER.get(info[q][0], 3), q))
    mode(">")
    for q in names:
        row(q, info[q][1], "qube:" + q)


def list_apps(qube):
    found = sorted(((n, i, p) for q, n, i, p in entries() if (q or "dom0") == qube),
                   key=lambda e: e[0].lower())
    mode(qube)
    for name, icon, path in found:
        row(name, icon, "app:" + path)
    # last, so Enter on the first row opens an app rather than going back
    row(BACK, "go-previous", "back")


def launch(path):
    # Detached and silent: rofi waits for its script's stdout to close.
    subprocess.Popen(["gio", "launch", path], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def main():
    retv = os.environ.get("ROFI_RETV", "0")
    info = os.environ.get("ROFI_INFO", "")
    if retv == "1" and info.startswith("qube:"):
        list_apps(info[5:])
    elif retv == "1" and info.startswith("app:"):
        launch(info[4:])                # no output: rofi closes
    else:
        list_qubes()                    # first call, or "back"


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.exit(0)
