# Linux SysAdmin Portfolio — Ilham Gadang Murakabi

Hi, I'm Ilham — a Linux system administrator based in Indonesia with around
5 years of hands-on experience at CDC Global Informatika (since September
2021). My day-to-day work is keeping Linux servers, MySQL databases, and web
stacks running: deploying sites to staging and production, setting up VPN
servers, migrating databases, and handling the IT support side when something
breaks.

This repository is my working toolbox — the scripts, templates, and playbooks
of the kind I actually use on the job. Nothing here is tied to a specific
client or company system; all IPs, hostnames, and credentials are placeholders
so the examples are safe to share and reuse.

## What's inside

| Area | Contents |
|---|---|
| [docker/](docker/) | A ready-to-run LEMP stack (Nginx + PHP-FPM + MySQL) in Docker Compose, plus notes on setting up a Docker host on a fresh Ubuntu/Debian server |
| [mysql/](mysql/) | A backup script with rotation, a step-by-step database migration guide, and the DBA queries I reach for most often |
| [vpn/](vpn/) | WireGuard server setup guide and OpenVPN setup notes with a client config template |
| [linux/](linux/) | Server hardening checklist + script, a quick health-check script, and an SSH key management guide |
| [deployment/](deployment/) | A simple, careful deploy script for LEMP websites (staging / production) |
| [nginx/](nginx/) | Nginx virtual host templates (PHP site + reverse proxy) and Certbot SSL steps |
| [backup/](backup/) | An rsync-based file backup script with snapshot rotation |

## Core skills

- **Linux administration** — Ubuntu/Debian servers, systemd, SSH, firewalls (UFW), Fail2ban, cron, log review
- **MySQL / SQL** — installation, user & privilege management, backup/restore, server-to-server migration, basic performance checks
- **Docker** — Docker Compose stacks, mostly LEMP, for dev/staging/production use
- **Web stack** — Nginx + PHP-FPM (LEMP), virtual hosts, Let's Encrypt SSL
- **VPN** — WireGuard and OpenVPN servers for remote access
- **Cloud** — Huawei Cloud server provisioning and management
- **Deployment** — staging → production rollouts, data entry & migration tasks
- **Also comfortable with** — PHP/CSS/JS basics, general IT support and troubleshooting

## A note on how I work

I prefer boring, well-understood tools, scripts I can read top to bottom, and
backups I've actually tested restoring. Most of what's here started as notes
to myself before it turned into something reusable.

## Contact

- LinkedIn: https://www.linkedin.com/in/ilham-gadang-371aba229/
- Open to remote work worldwide — full-time roles and freelance projects in
  Linux administration, MySQL DBA work, and IT support.
