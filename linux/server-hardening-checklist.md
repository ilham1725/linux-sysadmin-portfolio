# Linux Server Hardening Checklist

What I run through on every new Ubuntu/Debian server before it does real
work. `hardening.sh` in this folder automates the SSH/firewall/fail2ban
basics; the rest is deliberate manual work.

## Accounts & access

- [ ] Create a named sudo user; don't work as root day-to-day
- [ ] SSH key login working for that user **before** changing SSH settings
- [ ] Password authentication disabled, root login disabled (see below)
- [ ] Remove unused default/system users; check `getent passwd`
- [ ] `sudo` requires a password; review `/etc/sudoers.d/`

## SSH (`/etc/ssh/sshd_config` or a drop-in in `sshd_config.d/`)

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
```

- [ ] Validate with `sshd -t`, then `systemctl reload ssh`
- [ ] Keep a second session open while changing SSH — lockouts are self-inflicted

## Updates

- [ ] `apt update && apt upgrade` done at handover
- [ ] `unattended-upgrades` enabled for security updates
- [ ] Kernel reboot scheduled if one is pending (`/var/run/reboot-required`)

## Firewall

- [ ] UFW enabled, default deny incoming
- [ ] Only needed ports open (usually 22 + the app's ports)
- [ ] Cloud security group matches the host firewall (both layers!)

## Brute-force & logs

- [ ] Fail2ban installed, `sshd` jail enabled, ban time sane (e.g. 1h+)
- [ ] `journalctl` / `auth.log` reviewed after setup; log rotation in place
- [ ] Time sync on (`timedatectl` — NTP active); wrong clocks break TLS & logs

## Services & exposure

- [ ] `ss -tulpn` — every listening port accounted for
- [ ] Unneeded services disabled (`systemctl list-unit-files --state=enabled`)
- [ ] Databases (MySQL etc.) bound to localhost or the private network only,
      never `0.0.0.0` on a public box without a firewall rule to match
- [ ] Docker hosts: remember published container ports bypass UFW — check
      `docker ps` too

## Backups & recovery

- [ ] Backups configured (files + database) and **one restore tested**
- [ ] Console/serial access at the cloud provider confirmed working —
      that's your way back in if SSH dies

## Ongoing

- [ ] Weekly: check `fail2ban-client status sshd`, failed logins, disk usage
- [ ] Monthly: apply updates, review users & SSH keys, test a restore
- [ ] When someone leaves: remove their user, keys, and VPN peer the same day
