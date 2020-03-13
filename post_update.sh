#!/bin/sh

echo "Initializing db"
service postgresql initdb

echo "Starting postgresql"
service postgresql start

USER="pgsql"
PG_CLIENT="/usr/local/bin/psql"
PG_HOST="/tmp"
DEST_DIR="/usr/local/ds-system"
PASS=`cat /root/dbpassword`
DUMP_FILE_PATH="/tmp/update_dump"

export LC_ALL=en_US.UTF-8

# Set a password on the postgres account
psql -d template1 -U ${USER} -c "ALTER USER ${USER} WITH PASSWORD '${PASS}';"

# Fix permission for postgres
echo "listen_addresses = '*'" >> /usr/local/pgsql/data/postgresql.conf
echo "host  all  all 0.0.0.0/0 md5" >> /usr/local/pgsql/data/pg_hba.conf

echo "Creating dssystem database"
${PG_CLIENT} -U ${USER} -h ${PG_HOST} -c "create database dssystem" -d template1

echo "Restore saved dump of postgresql"
psql -U pgsql -d dssystem -1 -f ${DUMP_FILE_PATH}
if [ $? = 0 ]; then
	rm -f ${DUMP_FILE_PATH}
else
	echo "Not removing ${DUMP_FILE_PATH} as restore command returned non-zero exit status" | tee -a /var/log/messages
	exit 1
fi
