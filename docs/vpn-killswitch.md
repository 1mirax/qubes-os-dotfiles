# VPN kill switch in Qubes (cheat sheet)

**Principle:** the forwarded traffic of the client qubes is not allowed to
leave through eth0 (interface group 1) towards sys-net. Amnezia's own traffic
goes through `output`, not `forward`, so it is not blocked.

The rule:

```sh
nft add rule ip qubes custom-forward oifgroup 1 counter drop
nft add rule ip6 qubes custom-forward oifgroup 1 counter drop
```

## Where it lives

In the template for the VPN qubes (`vpn-template`), as root:
`/etc/qubes/qubes-firewall.d/90-vpn-killswitch` — first line `#!/bin/sh`, then
the rules, then `chmod +x`. That template is for VPN qubes only, not for
sys-net or sys-firewall.

The files in this repository:

```
template/vpn/90-vpn-killswitch   the kill switch
template/vpn/91-vpn-dns          sends the clients' DNS (Qubes' 10.139.1.1/.2) to the VPN's DNS
```

`/etc/qubes/qubes-firewall.d/90-vpn-killswitch`:

```sh
#!/bin/sh
nft add rule ip qubes custom-forward oifgroup 1 counter drop
nft add rule ip6 qubes custom-forward oifgroup 1 counter drop
```

`/etc/qubes/qubes-firewall.d/91-vpn-dns`:

```sh
#!/bin/sh
nft delete table ip vpn-dns 2>/dev/null
nft add table ip vpn-dns
nft add chain ip vpn-dns prerouting '{ type nat hook prerouting priority -110; }'
nft add rule ip vpn-dns prerouting ip daddr '{ 10.139.1.1, 10.139.1.2 }' udp dport 53 dnat to 172.29.172.254
nft add rule ip vpn-dns prerouting ip daddr '{ 10.139.1.1, 10.139.1.2 }' tcp dport 53 dnat to 172.29.172.254
```

Both files must be executable (`chmod +x`). To see what is actually there, in
`vpn-template`:

```sh
cat /etc/qubes/qubes-firewall.d/90-vpn-killswitch /etc/qubes/qubes-firewall.d/91-vpn-dns
```

## Check

In the VPN qube, with sudo:

```sh
nft list chain ip qubes custom-forward
nft list chain ip6 qubes custom-forward
```

One rule in each. Test: ping from a client → turn Amnezia off → the ping
stops and the rule's `packets` counter grows.

It can be checked at three points: what the internet sees, what goes through
A, and what sys-net sees. For example: A is connected to server A, B to
server B, and the client sits behind B.

## Remember

- Run nothing in the VPN qube itself: the rule doesn't protect its own
  traffic.
- Amnezia's built-in kill switch is off.
- It only works with VPNs that create an interface (`amn0`, `wg0`, `tun0`).
