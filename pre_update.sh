#!/bin/sh

pgsql_id="$(id -u pgsql)"
if [ "${pgsql_id}" != "769" ]; then
	echo "Changing uid/gid of user/group pgsql"
	pw groupmod -n pgsql -g 769
	pw usermod -n pgsql -u 769 -g pgsql
	find / -uid "${pgsql_id}" -exec chown -R pgsql:pgsql {} +
fi

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
rm -rf /usr/local/pgsql/data/* || true
