# Nginx Virtual Host Templates

The two vhost shapes I use constantly on LEMP servers: a PHP site served by
PHP-FPM, and a reverse proxy in front of an app. Replace `example.com` and
paths with your own. Test with `sudo nginx -t` before every reload.

## 1. PHP website (LEMP)

`/etc/nginx/sites-available/example.com`:

```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    root /var/www/example.com;
    index index.php index.html;

    access_log /var/log/nginx/example.com.access.log;
    error_log  /var/log/nginx/example.com.error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        # Debian/Ubuntu PHP-FPM socket — match your PHP version
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    # Don't serve dotfiles (.env, .git, ...)
    location ~ /\.(?!well-known) {
        deny all;
    }

    # Static assets: cache hard, log less
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }

    client_max_body_size 32m;
}
```

Enable:

```bash
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 2. Reverse proxy (app on localhost:3000)

```nginx
server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # WebSocket support — harmless if the app doesn't use it
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
    }

    client_max_body_size 32m;
}
```

## 3. HTTPS with Certbot (Let's Encrypt)

```bash
sudo apt install -y certbot python3-certbot-nginx

# Get the cert and let Certbot patch the vhost + add the HTTP→HTTPS redirect
sudo certbot --nginx -d example.com -d www.example.com

sudo nginx -t && sudo systemctl reload nginx
```

Verify renewal works (Certbot installs a systemd timer automatically):

```bash
systemctl list-timers | grep certbot
sudo certbot renew --dry-run
```

Things that bite people:

- The domain must already point at this server (DNS A record) and port 80
  must be reachable, or validation fails.
- Certbot edits the vhost in `sites-available` — if you later overwrite the
  file from a template, re-check the SSL block it added.
- Certificates last 90 days; if the dry-run passes, renewals are on autopilot.

## 4. Force HTTPS manually (if not using Certbot's redirect)

```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;
}
```
