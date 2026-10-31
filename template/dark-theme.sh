#!/bin/sh
# Dark theme for every GTK and Qt app in the qubes of a template.
# Run as root in the template (Debian or Fedora), not dom0.
#
# GTK reads /etc/gtk-*/settings.ini; Qt is told to take its colours from
# GTK. A qube's own ~/.config/gtk-3.0/settings.ini still wins. Undo: delete
# the files listed at the end.
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sh $0" >&2; exit 1
fi

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*) apt-get install -y -q qt6-gtk-platformtheme ;;
    *" fedora "*|*" rhel "*)   ;;      # the GTK plugin ships in qt6-qtbase-gui
    *) echo "Unsupported template: ${PRETTY_NAME:-unknown}" >&2; exit 1 ;;
esac

install -d -m 0755 /etc/gtk-3.0 /etc/gtk-4.0
cat > /etc/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF
cat > /etc/gtk-4.0/settings.ini <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
EOF

# Sourced when the qube's X session starts: Xsession.d on Debian (run-parts
# skips names with a dot), xinitrc.d on Fedora (skips files without +x).
for d in /etc/X11/Xsession.d /etc/X11/xinit/xinitrc.d; do
    [ -d "$d" ] || continue
    echo 'export QT_QPA_PLATFORMTHEME=gtk3' > "$d/90dark-theme"
    chmod 0755 "$d/90dark-theme"
    echo "$d/90dark-theme"
done
echo /etc/gtk-3.0/settings.ini /etc/gtk-4.0/settings.ini
