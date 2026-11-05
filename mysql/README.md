# MySQL

Tools and notes from my MySQL DBA work.

## Contents

- **mysql-backup.sh** — full backup with `mysqldump` (single-transaction,
  includes routines/triggers/events), gzip compression, and old-backup
  rotation. Backs up one database or all of them.
- **mysql-migration-guide.md** — how I move a database from one server to
  another with checks before and after.
- **common-dba-tasks.md** — user/privilege management, slow-query checks, and
  the inspection queries I use most.

## Backup script quick start

```bash
# 1. Create a MySQL user for backups (see common-dba-tasks.md)
# 2. Store its credentials in ~/.my.cnf (chmod 600)
chmod +x mysql-backup.sh
./mysql-backup.sh            # all databases
./mysql-backup.sh appdb      # just one
```

Test a restore at least once — a backup you've never restored is a hope,
not a backup:

```bash
gunzip -c /var/backups/mysql/appdb_2026-01-01_023000.sql.gz | mysql appdb_test
```
