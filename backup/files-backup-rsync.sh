#!/usr/bin/env bash
#
# files-backup-rsync.sh — snapshot-style file backup with rsync
#
# Creates timestamped snapshot folders. Unchanged files are hard-linked
# against the previous snapshot (--link-dest), so each snapshot looks like
# a full copy but only changed files take new disk space.
#
# Usage:
#   ./files-backup-rsync.sh                 # use the defaults below
#   SRC=/var/www DEST=/mnt/backup/www KEEP=14 ./files-backup-rsync.sh
#   ./files-backup-rsync.sh --dry-run       # show what would happen
#
# Cron example (daily at 03:15):
#   15 3 * * * /opt/scripts/files-backup-rsync.sh >> /var/log/files-backup.log 2>&1

set -euo pipefail

SRC="${SRC:-/var/www}"              # what to back up (no trailing slash)
DEST="${DEST:-/mnt/backup/files}"   # where snapshots live (ideally another disk/server)
KEEP="${KEEP:-7}"                   # how many snapshots to keep
TIMESTAMP="$(date +%F_%H%M%S)"
DRY_RUN=""
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN="--dry-run"

mkdir -p "$DEST"

LATEST_LINK="${DEST}/latest"
SNAPSHOT="${DEST}/${TIMESTAMP}"
LINK_DEST=""
if [[ -d "${LATEST_LINK}" ]]; then
  LINK_DEST="--link-dest=${LATEST_LINK}"
fi

echo "[$(date '+%F %T')] Backing up ${SRC} -> ${SNAPSHOT}"
# shellcheck disable=SC2086  # LINK_DEST is intentionally word-split (may be empty)
rsync -aHAX --delete $DRY_RUN $LINK_DEST \
  --exclude='/cache/' \
  --exclude='*.log' \
  "${SRC}/" "${SNAPSHOT}/"

if [[ -z "$DRY_RUN" ]]; then
  # Point "latest" at the new snapshot
  ln -sfn "$SNAPSHOT" "$LATEST_LINK"

  # Rotation: keep only the newest $KEEP snapshots
  mapfile -t SNAPSHOTS < <(find "$DEST" -maxdepth 1 -type d -name '20??-*' | sort)
  COUNT=${#SNAPSHOTS[@]}
  if (( COUNT > KEEP )); then
    REMOVE=$(( COUNT - KEEP ))
    for (( i=0; i<REMOVE; i++ )); do
      echo "Removing old snapshot: ${SNAPSHOTS[i]}"
      rm -rf "${SNAPSHOTS[i]}"
    done
  fi
fi

echo "[$(date '+%F %T')] Backup done."
