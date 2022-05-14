# postgres_table_recovery
Tool for quick search and fix of corrupted fields in large PostgreSQL tables.

## Problem: missing chunk number 0 for toast value

You may get this message upon PostgreSQL startup:

```
ERROR: missing chunk number 0 for toast value 734921 in pg_toast_83651
```

This means that your database was corrupted due to some reason, e.g. hardware faults (HDD, cache, RAID, etc.). See [Wiki](https://wiki.postgresql.org/wiki/Corruption) for more details. It is likely that a corrupted chunk is present in the postgres table file, but it can be fixed.

## Manual solution

According to this [solution](https://gist.github.com/supix/80f9a6111dc954cf38ee99b9dedf187a), you may manually identify the corrupted fields in your table by running commands sequentially:

```
psql -U postgres -d mydatabase -c "select * from mytable order by id limit 5000 offset 0" > /dev/null || echo "Corrupted chunk read!"
psql -U postgres -d mydatabase -c "select * from mytable order by id limit 5000 offset 5000" > /dev/null || echo "Corrupted chunk read!"
psql -U postgres -d mydatabase -c "select * from mytable order by id limit 5000 offset 10000" > /dev/null || echo "Corrupted chunk read!"
psql -U postgres -d mydatabase -c "select * from mytable order by id limit 5000 offset 15000" > /dev/null || echo "Corrupted chunk read!"
...
```

or scratch up a script to have some automation:

```
#!/bin/sh
n=0
while [ $n -lt 58223 ]
do
  psql -U postgres -d database -c "select * from mytable limit 1 offset $n" >/dev/null || echo $n
  n=$(($n+1))
done
```

## Large table automated search



