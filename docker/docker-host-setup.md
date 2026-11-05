# Setting Up a Docker Host on Ubuntu / Debian

How I prepare a fresh Ubuntu (22.04/24.04) or Debian (12) server to run
Docker containers. Assumes a sudo user and SSH key access already set up
(see [../linux/](../linux/) for hardening).

## 1. Install Docker Engine (official repo)

```bash
sudo apt update
sudo apt install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
# For Debian, use: https://download.docker.com/linux/debian/gpg
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verify:

```bash
sudo systemctl enable --now docker
sudo docker run hello-world
docker compose version
```

## 2. Let your user run Docker without sudo (optional)

```bash
sudo usermod -aG docker $USER
# log out and back in for the group change to apply
```

> ⚠️ The `docker` group is effectively root-equivalent. Only add trusted
> admin users.

## 3. Log rotation (do this before the disk fills up)

Containers log to JSON files that grow forever by default. Cap them in
`/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

```bash
sudo systemctl restart docker
```

## 4. Basic host hygiene for a Docker box

- Firewall the host with UFW (see the hardening checklist) — remember that
  **Docker publishes ports by bypassing UFW rules** for the INPUT chain in
  many setups. Avoid publishing ports you don't need; bind internal services
  to `127.0.0.1` (e.g. `127.0.0.1:3306:3306`).
- Never expose the Docker daemon socket over TCP without TLS.
- Keep the host updated: `sudo apt update && sudo apt upgrade` on a schedule,
  and enable unattended security upgrades.
- Prune old images/build cache occasionally:
  `docker system df` to check, `docker image prune` to clean.

## 5. First project

```bash
mkdir -p ~/apps && cd ~/apps
# copy a stack (e.g. lemp-stack/) here, then:
docker compose up -d
docker compose ps
docker compose logs -f
```
