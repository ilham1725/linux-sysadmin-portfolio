# Migrating a MySQL Database Between Servers

The process I follow when moving a database from an old server to a new one
(e.g. `old-server.example.com` → `new-server.example.com`). Plain mysqldump —
simple, predictable, and fine for small-to-medium databases. For very large
or zero-downtime moves, plan a replication-based cutover instead.

## 0. Before you touch anything

- [ ] Take a fresh backup on the source (see `mysql-backup.sh`) and keep it
      until the migration is confirmed good.
- [ ] Compare versions — migrating to the same or a newer MySQL version is
      the safe direction:

```sql
SELECT VERSION();
```

- [ ] Check database sizes so you know the dump will fit and roughly how
      long it will take:

```sql
SELECT table_schema,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC;
```

- [ ] List users and grants on the source — `mysqldump` does **not** move
      users. Recreate the app user on the target:

```sql
SELECT user, host FROM mysql.user;
SHOW GRANTS FOR 'appuser'@'%';
```

- [ ] Agree a maintenance window if the app can't tolerate writes during
      the dump (a `--single-transaction` dump is consistent for InnoDB,
      but new writes after the dump starts still won't be in it).

## 1. Dump on the source server

```bash
mysqldump --single-transaction --routines --triggers --events \
  --set-gtid-purged=OFF \
  -h old-server.example.com -u root -p appdb | gzip > appdb.sql.gz
```

- `--single-transaction` — consistent snapshot for InnoDB without locking.
- `--routines --triggers --events` — stored procedures, triggers, and events
  are **not** included by default; forgetting them is the classic migration bug.
- Leave out `--set-gtid-purged=OFF` only if both servers use GTID and you
  know you want the GTID state carried over.

## 2. Transfer

```bash
rsync -avh --progress appdb.sql.gz new-server.example.com:/tmp/
# or: scp appdb.sql.gz new-server.example.com:/tmp/
```

## 3. Import on the target server

```bash
mysql -u root -p -e "CREATE DATABASE appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
gunzip -c /tmp/appdb.sql.gz | mysql -u root -p appdb
```

Recreate the application user with the same grants as on the source:

```sql
CREATE USER 'appuser'@'%' IDENTIFIED BY 'new-strong-password';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
-- (copy the exact grant list from SHOW GRANTS on the source — least privilege wins)
```

## 4. Verify before switching the app over

Table counts and a spot check:

```sql
-- run on BOTH servers and compare
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'appdb'
ORDER BY table_name;
```

> Note: `table_rows` is an estimate for InnoDB. For critical tables use
> `SELECT COUNT(*)` on both sides.

Checksums for a stronger check on important tables:

```sql
CHECKSUM TABLE appdb.orders, appdb.customers;  -- compare values both sides
```

Also check: row counts on the biggest tables, a few `SELECT`s the app
actually runs, and that stored procedures/triggers/events exist:

```sql
SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'appdb';
SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'appdb';
SELECT COUNT(*) FROM information_schema.events   WHERE event_schema   = 'appdb';
```

## 5. Cutover and rollback

1. Point the app config at the new server (host `new-server.example.com`).
2. Watch the app logs and MySQL error log for the first hour.
3. Keep the old server untouched (read-only if possible) for a few days —
   if something is wrong, switching the config back is your rollback.
4. Only decommission the old database after the new one has run clean
   through at least one full backup cycle.
