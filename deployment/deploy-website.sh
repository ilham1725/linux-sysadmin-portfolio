#!/usr/bin/env bash
#
# deploy-website.sh — simple deploy for a PHP (LEMP) website from Git
#
# Pulls the latest code, fixes ownership/permissions, optionally installs
# Composer dependencies, restarts PHP-FPM, and checks the site answers.
#
# The environment is an argument, so staging and production can never be
# confused by editing the wrong line:
#
#   ./deploy-website.sh staging
#   ./deploy-website.sh production
#
# Edit the CONFIG section for your paths/services. Run as the user that
# owns the site files (or via sudo).

set -euo pipefail

ENV="${1:-}"
case "$ENV" in
  staging)
    SITE_DIR="/var/www/staging.example.com"
    BRANCH="staging"
    PHP_SERVICE="php8.3-fpm"
    SITE_URL="https://staging.example.com"
    ;;
  production)
    SITE_DIR="/var/www/example.com"
    BRANCH="main"
    PHP_SERVICE="php8.3-fpm"
    SITE_URL="https://example.com"
    ;;
  *)
    echo "Usage: $0 {staging|production}" >&2
    exit 1
    ;;
esac

echo "==> Deploying ${ENV} (${SITE_DIR}, branch ${BRANCH})"

cd "$SITE_DIR"

# Refuse to deploy over uncommitted local changes — they usually mean
# someone hot-fixed the server and that fix is not in Git yet.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is dirty. Commit, stash, or investigate first:" >&2
  git status --short >&2
  exit 1
fi

PREV_COMMIT="$(git rev-parse --short HEAD)"

git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

NEW_COMMIT="$(git rev-parse --short HEAD)"
echo "==> ${PREV_COMMIT} -> ${NEW_COMMIT}"

# PHP dependencies, only when a composer.json exists
if [[ -f composer.json ]]; then
  composer install --no-dev --optimize-autoloader --no-interaction
fi

# Ownership & permissions: web server user owns content, dirs 755, files 644
sudo chown -R www-data:www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 755 {} +
find "$SITE_DIR" -type f -exec chmod 644 {} +
# keep the deploy key / git metadata out of the web root's business
chmod 700 "$SITE_DIR/.git" 2>/dev/null || true

# Restart PHP-FPM to pick up code + clear opcache
sudo systemctl restart "$PHP_SERVICE"
sudo systemctl reload nginx

# Smoke test: the site must answer with a 200 (or a redirect to one)
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$SITE_URL" || echo '000')"
echo "==> ${SITE_URL} answered HTTP ${HTTP_CODE}"

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "301" && "$HTTP_CODE" != "302" ]]; then
  echo "WARNING: unexpected HTTP status. Previous commit was ${PREV_COMMIT}." >&2
  echo "Rollback: cd ${SITE_DIR} && git reset --hard ${PREV_COMMIT} && sudo systemctl restart ${PHP_SERVICE}" >&2
  exit 1
fi

echo "==> Deploy OK: ${ENV} @ ${NEW_COMMIT}"
