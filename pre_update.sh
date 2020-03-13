#!/bin/sh

echo "Generating dump of postgresql"
rm -f /tmp/update_dump
pg_dump -U pgsql -d dssystem > /tmp/update_dump

echo "Stopping postgresql"
service postgres stop

echo "Deleting postgresql packages"
pkg info | grep postgresql | awk '{print $1}' | xargs pkg delete -yf

echo "Removing postgresql data directory"
# We do this as newer version of postgresql probably won't support the directory
# initialised by an older version of postgresql
rm -rf /usr/local/pgsql/data
