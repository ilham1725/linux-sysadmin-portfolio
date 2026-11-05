# WireGuard VPN Server Setup (Ubuntu / Debian)

Step-by-step setup of a WireGuard server for remote access — the approach I
use when a small team needs to reach internal services safely. Example
values: server public IP `203.0.113.10`, VPN subnet `10.8.0.0/24`,
port `51820/UDP`.

## 1. Install

```bash
sudo apt update
sudo apt install -y wireguard
```

## 2. Generate server keys

```bash
cd /etc/wireguard
sudo sh -c 'umask 077; wg genkey > server_private.key'
sudo sh -c 'cat server_private.key | wg pubkey > server_public.key'
```

## 3. Server config — `/etc/wireguard/wg0.conf`

```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <server_private_key>

# NAT so clients can reach the LAN / internet through this server
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# --- one [Peer] block per client (see step 5) ---
[Peer]
PublicKey = <client_public_key>
AllowedIPs = 10.8.0.2/32
```

Replace `eth0` with your actual WAN interface (`ip route | grep default`).

## 4. Enable IP forwarding + firewall

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-wireguard.conf
sudo sysctl --system

sudo ufw allow 51820/udp
sudo ufw allow OpenSSH
sudo ufw enable
```

## 5. Add a client

Generate keys **on the client**, then add its public key as a `[Peer]` on
the server (config above), and give the client this config:

```ini
[Interface]
Address = 10.8.0.2/24
PrivateKey = <client_private_key>
DNS = 1.1.1.1

[Peer]
PublicKey = <server_public_key>
Endpoint = 203.0.113.10:51820
# Full tunnel: 0.0.0.0/0 — split tunnel: use your LAN subnet, e.g. 192.168.1.0/24, 10.8.0.0/24
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

## 6. Start the server

```bash
sudo systemctl enable --now wg-quick@wg0
sudo wg show              # check peers & handshakes
```

Apply peer changes without a restart:

```bash
sudo wg syncconf wg0 <(sudo wg-quick strip wg0)
```

## Troubleshooting quickies

- No handshake: UDP port blocked (cloud security group? UFW?), wrong
  endpoint, or clock skew.
- Handshake OK but no traffic: IP forwarding off, wrong `AllowedIPs`, or the
  NAT `PostUp` interface name is wrong.
- `sudo wg show` — a peer with no "latest handshake" has never connected.

## Habits that keep this sane

- One peer per device, not per person — revoke by deleting one block.
- Keep a simple list mapping `10.8.0.x` → device/owner.
- WireGuard keys are the whole security model: private keys stay on their
  own machine, never in chat/email.
