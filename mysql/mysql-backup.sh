#!/usr/bin/env bash
#
# mysql-backup.sh — full MySQL backup with mysqldump + rotation
#
# Backs up either one database or all databases, compresses with gzip,
# and deletes backups older than RETENTION_DAYS.
#
# Credentials: this script expects a ~/.my.cnf with a [mysqldump] section
# so no password ever appears on the command line:
#
#   [mysqldump]
#   user=backup
#   password=your-password
#
# chmod 600 ~/.my.cnf
#
# Usage:
#   ./mysql-backup.sh              # back up ALL databases
#   ./mysql-backup.sh mydb         # back up only "mydb"
#   BACKUP_DIR=/mnt/backups/mysql RETENTION_DAYS=14 ./mysql-backup.sh
#
# Cron example (daily at 02:30):
#   30 2 * * * /opt/scripts/mysql-backup.sh >> /var/log/mysql-backup.log 2>&1

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%F_%H%M%S)"
DB_NAME="${1:-}"

mkdir -p "$BACKUP_DIR"

if [[ -n "$DB_NAME" ]]; then
  OUTFILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
  echo "[$(date '+%F %T')] Backing up database: ${DB_NAME}"
  mysqldump --single-transaction --routines --triggers --events \
    "$DB_NAME" | gzip > "$OUTFILE"
else
  OUTFILE="${BACKUP_DIR}/all-databases_${TIMESTAMP}.sql.gz"
  echo "[$(date '+%F %T')] Backing up ALL databases"
  mysqldump --single-transaction --routines --triggers --events \
    --all-databases | gzip > "$OUTFILE"
fi

echo "[$(date '+%F %T')] Written: ${OUTFILE} ($(du -h "$OUTFILE" | cut -f1))"

# Rotation: remove backups older than RETENTION_DAYS
find "$BACKUP_DIR" -name '*.sql.gz' -type f -mtime +"$RETENTION_DAYS" -print -delete

echo "[$(date '+%F %T')] Done."
