#!/bin/sh
# VPN template on debian-13-minimal: Throne, kill switch, client DNS, plus
# the dark theme and the dark tray from the folder above.
# Run as root in the template (not dom0), with the whole template/ folder of
# this repository copied over. See docs/vpn-killswitch.md.
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sh $0" >&2; exit 1
fi
cd "$(dirname "$0")"

# networking: qubes-firewall, which loads the kill switch; passwordless-root:
# sudo in the VPN qube, for checking the rules.
apt-get update -q
apt-get install -y -q qubes-core-agent-networking qubes-core-agent-passwordless-root \
    curl ca-certificates

# Throne's signed APT repository. Templates have no network: curl goes
# through the Qubes updates proxy, as apt does.
install -d -m 0755 /etc/apt/keyrings
curl -fsSL --proxy http://127.0.0.1:8082 -o /etc/apt/keyrings/throne.asc \
    https://throneproj.github.io/Throne/throne.asc
curl -fsSL --proxy http://127.0.0.1:8082 -o /etc/apt/sources.list.d/throne.list \
    https://throneproj.github.io/Throne/apt/throne.list
apt-get update -q
apt-get install -y -q throne

# TUN needs a root core. Throne asks for it through pkexec, but in an app
# qube /opt comes from the template and the change is gone after a reboot,
# so it is done here, and again after every upgrade replaces the file.
CORE=/opt/Throne/ThroneCore
chown root:root "$CORE" && chmod u+s "$CORE"
cat > /etc/apt/apt.conf.d/99throne-core <<EOF
DPkg::Post-Invoke { "if [ -f $CORE ]; then chown root:root $CORE && chmod u+s $CORE; fi"; };
EOF

# TCP protocols (VLESS, Trojan, ...) find a working packet size by
# themselves, also where a mobile network silently drops big packets.
cat > /etc/sysctl.d/90-mtu-probing.conf <<'EOF'
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 1024
EOF

install -d -m 0755 /etc/qubes/qubes-firewall.d
install -m 0755 90-vpn-killswitch 91-vpn-dns 92-vpn-tun-input /etc/qubes/qubes-firewall.d/

sh ../dark-theme.sh
bash ../install-tray-bg.sh

echo "Done. Shut the template down, then create the VPN qube from it."
