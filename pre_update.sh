#!/bin/sh

echo "Starting postgresql service"
service postgresql start

echo "Generating dump of postgresql"
rm -f /tmp/update_dump
pg_dump -U pgsql -d dssystem > /tmp/update_dump

if [ $? != 0 ]; then
	echo "Failed to take dump of existing database. Aborting update."
	exit 1
fi

echo "Stopping postgresql"
service postgresql stop

echo "Removing postgresql data directory"
# We do this as newer version of postgresql probably won't support the directory
# initialised by an older version of postgresql
rm -rf /usr/local/pgsql/data/* | true
