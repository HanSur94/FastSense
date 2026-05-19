# Multicast Firewall Rule for FastSense v4.0

FastSense uses MATLAB `udpport` multicast on the IPv4 site-local admin scope
`239.192.40.x` (RFC 2365) for ack-propagation hints. Disk state is the
canonical source of truth — multicast is a low-latency notification only,
NOT a delivery guarantee.

**Default group:** `239.192.40.1`
**Default port:** `40000` (configurable via the `UdpPort` NV-pair on Companion startup)

## Windows Defender Firewall

Run as Administrator:

```powershell
New-NetFirewallRule -DisplayName "FastSense v4 Multicast" `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 40000 `
    -RemoteAddress 239.192.40.0/24 `
    -Action Allow `
    -Profile Private
```

Reverse with `Remove-NetFirewallRule -DisplayName "FastSense v4 Multicast"`.

On first MATLAB launch in cluster mode, Windows Defender may prompt to allow
`MATLAB.exe` on private networks — approve. Do NOT approve public networks.

## macOS pfctl + Application Firewall

macOS Application Firewall (the GUI one in System Settings) generally does
NOT block outbound UDP multicast. The first time you launch MATLAB in
cluster mode, you may get a prompt for "incoming network connections" — this
is for `udpport` listening on the multicast group. Approve.

If you use `pfctl` (raw packet filter), append to `/etc/pf.conf`:

```
pass in proto udp from any to 239.192.40.0/24 port 40000
pass out proto udp from any to 239.192.40.0/24 port 40000
```

Reload: `sudo pfctl -f /etc/pf.conf`.

## Linux iptables / nftables

`iptables`:

```bash
sudo iptables -A INPUT  -p udp -d 239.192.40.0/24 --dport 40000 -j ACCEPT
sudo iptables -A OUTPUT -p udp -d 239.192.40.0/24 --dport 40000 -j ACCEPT
```

`firewalld` (Red Hat / Fedora):

```bash
sudo firewall-cmd --permanent --add-rich-rule= \
    'rule family="ipv4" destination address="239.192.40.0/24" \
     port port="40000" protocol="udp" accept'
sudo firewall-cmd --reload
```

`nftables`:

```bash
sudo nft add rule inet filter input  ip daddr 239.192.40.0/24 udp dport 40000 accept
sudo nft add rule inet filter output ip daddr 239.192.40.0/24 udp dport 40000 accept
```

## Switch / Router Multicast Filtering

Some managed switches default to IGMP snooping with multicast restricted.
If only some Companions see ack hints (others wait the full ~5s for the
on-disk poll), check switch IGMP querier behaviour with your network admin.

FastSense falls back to UDP broadcast `255.255.255.255` on the same port
when multicast traffic is dropped. The fallback is detectable at startup
via the one-time warning:

```
Warning: Concurrency:multicastFallback
Multicast 239.192.40.0/24 not reachable; falling back to broadcast.
Ack propagation latency may increase to ~10s.
```

## Why 239.192.40.x?

The IPv4 site-local admin scope (`239.192.0.0/14`, RFC 2365) is the
recommended scope for organisation-private multicast that should NOT cross
router boundaries. FastSense reserves `239.192.40.x` to avoid conflicts
with common enterprise reserved blocks (Bonjour: 224.0.0.251; OSPF:
224.0.0.5; etc).

To change the multicast group / port, pass the NV-pairs at Companion
construction time:

```matlab
app = FastSenseCompanion('SharedRoot', root, 'MulticastGroup', '239.192.40.7', 'UdpPort', 40123);
```

(Multicast group + port configuration is forward-looking; current implementation
uses the defaults shown above.)
