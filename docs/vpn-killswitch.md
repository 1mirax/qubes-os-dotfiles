# VPN qube: Throne and a kill switch

A VPN qube (`sys-vpn`) on `debian-13-minimal` with
[Throne](https://github.com/throneproj/Throne) (VLESS, AmneziaWG and more).
Other qubes use it as their netvm; if the tunnel drops, their traffic stops
instead of going out bare.

**Principle:** the forwarded traffic of the client qubes is not allowed to
leave through eth0 (interface group 1) towards sys-net. Throne's own traffic
goes through `output`, not `forward`, so it is not blocked.

```
template/vpn/setup.sh            run as root in the template: installs everything below
template/vpn/90-vpn-killswitch   the kill switch
template/vpn/91-vpn-dns          sends the clients' DNS (Qubes' 10.139.1.1/.2) into the tunnel
```

## Install

In dom0:

```sh
qvm-template install debian-13-minimal     # if it isn't there yet
qvm-clone debian-13-minimal vpn-template
```

In a qube with network, get this repository and copy the folder over:

```sh
qvm-copy-to-vm vpn-template qubes-os-dotfiles/template/vpn
```

In dom0 (`<qube>` is the one you copied from):

```sh
qvm-run -p -u root vpn-template 'sh /home/user/QubesIncoming/<qube>/vpn/setup.sh'
qvm-shutdown --wait vpn-template

qvm-create --class AppVM --template vpn-template --label blue sys-vpn
qvm-prefs sys-vpn provides_network true
qvm-prefs sys-vpn netvm sys-firewall
qvm-run sys-vpn '/opt/Throne/Throne -appdata'
```

`-appdata` keeps Throne's settings in sys-vpn's own `~/.config/Throne`;
without it they go to `/opt/Throne`, which comes from the template and is
reset on every reboot. The menu entry already has it.

In Throne: import the profiles, turn on **TUN mode**, leave Throne's own kill
switch off (the nft rule does the job). Then point the client qubes at it:

```sh
qvm-prefs <client> netvm sys-vpn
```

## The rules

`/etc/qubes/qubes-firewall.d/90-vpn-killswitch`:

```sh
#!/bin/sh
nft add rule ip qubes custom-forward oifgroup 1 counter drop
nft add rule ip6 qubes custom-forward oifgroup 1 counter drop
```

`91-vpn-dns` sends the clients' DNS to `1.1.1.1`. That address goes into the
tunnel, where Throne answers it with its own DNS; with no tunnel it hits the
kill switch. Change `DNS=` at the top to use another resolver.

They live in the template, so every qube on it gets them. That template is
for VPN qubes only, not for sys-net or sys-firewall.

## Check

In sys-vpn:

```sh
sudo nft list chain ip qubes custom-forward
sudo nft list chain ip6 qubes custom-forward
```

One rule in each. Test: ping from a client → turn Throne off → the ping stops
and the rule's `packets` counter grows. DNS: `getent hosts example.com` in a
client works with Throne on and fails with it off.

## Remember

- Run nothing in sys-vpn itself except Throne: the rule doesn't protect the
  qube's own traffic.
- It only works with TUN mode (the `throne-tun` interface); proxy mode
  leaves the clients nothing to route through.
- An upgrade of Throne in the template keeps TUN working: an apt hook gives
  the new core root again.
