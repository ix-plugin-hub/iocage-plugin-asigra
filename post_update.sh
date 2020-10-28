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

echo "Updating database"

if [ -n "`${PG_CLIENT} -U ${USER} -h ${PG_HOST} -l -d template1  | grep dssystem`" ]; then
	MAX=`for i in ${DEST_DIR}/db/dssp*.sql; do
		echo ${i##*/}
	done | sed -e "s/dssp//g" -e "s/.sql//g" | awk 'BEGIN{max=0}{if ($1 > max)max=$1}END{print max}'`
	db_number=`${PG_CLIENT} -U ${USER} -h ${PG_HOST} -c "select db_number from ds_data" -d dssystem | sed -n "3p" | awk '{print $1}'`
	if [ -n "`echo $db_number | grep -E '^-?[0-9][0-9]*$'`" ]; then
		if [ "`echo $db_number | grep -E -o '^-'`" == "-" ]; then
			db_number=`echo $db_number | sed "s/^-//g"`
		fi
	fi
	db_number=`expr $db_number + 1`
	while [ $MAX -ge $db_number ]; do
		echo "Applying patch dssp${db_number}.sql"
		${PG_CLIENT} -U ${USER} -h ${PG_HOST} -f ${DEST_DIR}/db/dssp${db_number}.sql -d dssystem
		db_number=`expr $db_number + 1`
	done
else
	echo "dssystem database not found"
fi
