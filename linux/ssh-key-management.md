# SSH Key Management

How I add, rotate, and clean up SSH keys on the servers I administer.

## Generate a key (on your own machine)

```bash
ssh-keygen -t ed25519 -C "your-name@your-device"
# store in ~/.ssh/id_ed25519, set a passphrase
```

Ed25519 is the default choice now. Use RSA 4096 only for old systems that
don't support it:

```bash
ssh-keygen -t rsa -b 4096 -C "your-name@your-device"
```

## Add a key to a server

The easy way:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server.example.com
```

Manually (or when fixing a broken setup):

```bash
# on the server, as the target user
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAA... your-name@your-device' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

The permissions are not optional — sshd ignores `authorized_keys` if the
home directory or `.ssh` is group/world-writable. Home dir should be at
most `755`.

## Hygiene rules for authorized_keys

- **One line per key, per device.** Comment every key with owner + device
  (`ilham@laptop`, `ilham@pc-office`) so future-you knows what can be deleted.
- Laptop lost or replaced → remove its line the same day. A key you can't
  identify is a key you should probably remove and re-issue.
- Never share one private key between people or machines.
- For jump/bastion-only access, restrict a key to one source IP:

```
from="203.0.113.50" ssh-ed25519 AAAA... ilham@laptop
```

- For automation keys, lock them to a single command where possible:

```
command="/opt/scripts/run-backup.sh",no-port-forwarding,no-agent-forwarding ssh-ed25519 AAAA... backup-bot
```

## Rotating a key

Rotation = add new, verify, remove old. In that order, always:

1. Generate the new key on the device.
2. Append the new public key to `authorized_keys` on every server.
3. Test login with the new key explicitly:
   `ssh -i ~/.ssh/id_ed25519_new user@server.example.com`
4. Only then delete the old key's line from `authorized_keys`.
5. Delete the old private key from the device.

## Auditing who can log in

```bash
# every account with a shell + whether it has keys
getent passwd | awk -F: '$7 !~ /(nologin|false)$/ {print $1, $6}'

# dump all authorized_keys with owners (as root)
for f in /home/*/.ssh/authorized_keys /root/.ssh/authorized_keys; do
  [ -f "$f" ] && echo "--- $f" && cat "$f"
done

# recent successful logins
grep 'Accepted' /var/log/auth.log | tail -20     # Debian/Ubuntu
journalctl -u ssh --since '7 days ago' | grep Accepted
```

If a key in the audit doesn't have an owner you recognise, that's a finding —
investigate before your next coffee, not after an incident.
