# LEMP Stack (Docker Compose)

Nginx + PHP-FPM + MySQL 8, the stack I use most often for PHP websites.
This is the minimal version I start from for local development and small
deployments.

## Layout

```
lemp-stack/
├── docker-compose.yml
├── nginx/
│   └── default.conf      # create this — a basic PHP vhost (see ../../nginx/)
└── site/                 # your PHP code goes here (index.php, etc.)
```

## Quick start

```bash
mkdir -p site nginx
# put a vhost in nginx/default.conf (template: ../../nginx/vhost-templates.md)
# put your code in site/
docker compose up -d
curl http://localhost
```

## Notes

- Change the default passwords in `docker-compose.yml` (or move them to a
  `.env` file and add `.env` to `.gitignore`) before using this anywhere real.
- MySQL is **not** exposed to the host by default. The PHP container reaches
  it at host `mysql`, port `3306`.
- Data persists in the `mysql-data` volume. `docker compose down -v` deletes
  it — careful.
- For production I put a reverse proxy or the host's Nginx in front and drop
  the published port, but for a small single-site box this setup works as-is
  behind a firewall.
