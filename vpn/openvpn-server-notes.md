# OpenVPN Server — Setup Notes

My outline for setting up an OpenVPN server (Ubuntu/Debian) when WireGuard
isn't an option — e.g. when clients or existing infrastructure already use
OpenVPN. UDP `1194`, subnet `10.9.0.0/24`, server at `203.0.113.10`.

## 1. Install & PKI

```bash
sudo apt update
sudo apt install -y openvpn easy-rsa

mkdir -p ~/easy-rsa && cd ~/easy-rsa
ln -s /usr/share/easy-rsa/* .
./easyrsa init-pki
./easyrsa build-ca nopass        # creates the certificate authority
./easyrsa build-server-full server nopass
./easyrsa gen-dh
openvpn --genkey secret ta.key   # tls-crypt key (static key mode)
```

Copy the material into place:

```bash
sudo mkdir -p /etc/openvpn/server
sudo cp pki/ca.crt pki/issued/server.crt pki/private/server.key \
        pki/dh.pem ta.key /etc/openvpn/server/
```

## 2. Server config — `/etc/openvpn/server/server.conf` (key directives)

```conf
port 1194
proto udp
dev tun
ca       /etc/openvpn/server/ca.crt
cert     /etc/openvpn/server/server.crt
key      /etc/openvpn/server/server.key
dh       /etc/openvpn/server/dh.pem
tls-crypt /etc/openvpn/server/ta.key
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"     # remove for split tunnel
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
```

Enable forwarding + NAT the same way as any VPN gateway:

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-openvpn.conf
sudo sysctl --system
sudo iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o eth0 -j MASQUERADE
sudo ufw allow 1194/udp

sudo systemctl enable --now openvpn-server@server
sudo systemctl status openvpn-server@server
```

## 3. Issue a client certificate

```bash
cd ~/easy-rsa
./easyrsa build-client-full laptop-01 nopass
```

Revoke when a device is lost/retired:

```bash
./easyrsa revoke laptop-01
./easyrsa gen-crl
sudo cp pki/crl.pem /etc/openvpn/server/
# add to server.conf:  crl-verify /etc/openvpn/server/crl.pem
```

## 4. Client config template (`client.ovpn`)

Give each user one self-contained file with the certs inlined:

```conf
client
dev tun
proto udp
remote 203.0.113.10 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3

<ca>
-----BEGIN CERTIFICATE-----
...contents of ca.crt...
-----END CERTIFICATE-----
</ca>
<cert>
-----BEGIN CERTIFICATE-----
...contents of pki/issued/laptop-01.crt...
-----END CERTIFICATE-----
</cert>
<key>
-----BEGIN PRIVATE KEY-----
...contents of pki/private/laptop-01.key...
-----END PRIVATE KEY-----
</key>
<tls-crypt>
-----BEGIN OpenVPN Static key V1-----
...contents of ta.key...
-----END OpenVPN Static key V1-----
</tls-crypt>
```

## Notes from experience

- One certificate per device — makes revocation painless.
- The `.ovpn` file contains a private key: hand it over through a secure
  channel, never plain email/chat, and treat a leaked file as a lost device.
- If clients connect but can't reach anything, it's almost always
  forwarding/NAT/firewall — check in that order.
- Prefer WireGuard for new setups (simpler, faster); keep OpenVPN where
  compatibility demands it.
