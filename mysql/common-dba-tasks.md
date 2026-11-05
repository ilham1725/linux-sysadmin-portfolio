# Common MySQL DBA Tasks

The queries and commands I use most in day-to-day MySQL administration
(MySQL 8). Replace placeholder names/passwords with your own.

## Users & privileges

```sql
-- Create an application user (app connects from any host in the LAN/VPN)
CREATE USER 'appuser'@'%' IDENTIFIED BY 'strong-password-here';
GRANT SELECT, INSERT, UPDATE, DELETE ON appdb.* TO 'appuser'@'%';

-- Read-only reporting user, localhost only
CREATE USER 'reporter'@'localhost' IDENTIFIED BY 'strong-password-here';
GRANT SELECT ON appdb.* TO 'reporter'@'localhost';

-- Dedicated backup user (enough for mysqldump --single-transaction)
CREATE USER 'backup'@'localhost' IDENTIFIED BY 'strong-password-here';
GRANT SELECT, LOCK TABLES, RELOAD, PROCESS, TRIGGER, EVENT, SHOW VIEW
  ON *.* TO 'backup'@'localhost';

-- Inspect and clean up
SHOW GRANTS FOR 'appuser'@'%';
SELECT user, host FROM mysql.user;
DROP USER 'olduser'@'%';              -- remove accounts that are no longer used
ALTER USER 'appuser'@'%' IDENTIFIED BY 'new-password-here';  -- rotate password
```

Rule of thumb: one user per application, least privilege, never let apps
connect as `root`.

## What's big? Database & table sizes

```sql
-- Databases by size
SELECT table_schema,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS size_mb
FROM information_schema.tables
GROUP BY table_schema ORDER BY size_mb DESC;

-- Biggest tables in one database
SELECT table_name,
       ROUND((data_length + index_length) / 1024 / 1024, 1) AS size_mb,
       table_rows
FROM information_schema.tables
WHERE table_schema = 'appdb'
ORDER BY size_mb DESC
LIMIT 20;

-- Index size vs data size per table (index bloat check)
SELECT table_name,
       ROUND(data_length / 1024 / 1024, 1)  AS data_mb,
       ROUND(index_length / 1024 / 1024, 1) AS index_mb
FROM information_schema.tables
WHERE table_schema = 'appdb'
ORDER BY index_mb DESC;
```

## Index inspection

```sql
SHOW INDEX FROM appdb.orders;

-- Unused indexes since server start (needs performance_schema, MySQL 8)
SELECT object_schema, object_name, index_name
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE object_schema = 'appdb' AND index_name IS NOT NULL
  AND count_star = 0 AND index_name <> 'PRIMARY';
```

> Check unused indexes over a representative period before dropping any —
> an index unused since a restart last night tells you nothing.

## Slow queries

Enable the slow query log (runtime, no restart):

```sql
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;                       -- seconds
SET GLOBAL slow_query_log_file = '/var/lib/mysql/slow.log';
```

Summarise it from the shell:

```bash
mysqldumpslow -s t -t 10 /var/lib/mysql/slow.log      # top 10 by time
```

Top digest queries from performance_schema:

```sql
SELECT LEFT(digest_text, 120) AS query_snippet,
       count_star AS execs,
       ROUND(sum_timer_wait / 1e12, 2) AS total_seconds
FROM performance_schema.events_statements_summary_by_digest
ORDER BY sum_timer_wait DESC
LIMIT 10;
```

Then `EXPLAIN` the worst offender and check it's using an index:

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 42 AND status = 'paid';
```

## Live checks

```sql
SHOW FULL PROCESSLIST;                 -- what's running right now
SHOW ENGINE INNODB STATUS\G            -- locks, deadlocks, buffer pool
SELECT * FROM performance_schema.data_locks;          -- current locks (8.0)
KILL 12345;                            -- stop a runaway query by thread id
```

## Maintenance basics

```sql
ANALYZE TABLE appdb.orders;            -- refresh index statistics
OPTIMIZE TABLE appdb.logs;             -- reclaim space (rebuilds the table — 
                                       -- schedule it, it can lock on big tables)
CHECK TABLE appdb.orders;              -- quick integrity check
```
