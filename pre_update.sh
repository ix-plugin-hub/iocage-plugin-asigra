#!/bin/sh

echo "Generating dump of postgresql"
rm -f /tmp/update_dump
pg_dump -U pgsql -d dssystem > /tmp/update_dump

echo "Stopping postgresql"
service postgresql stop

echo "Removing postgresql data directory"
# We do this as newer version of postgresql probably won't support the directory
# initialised by an older version of postgresql
rm -rf /usr/local/pgsql/data
