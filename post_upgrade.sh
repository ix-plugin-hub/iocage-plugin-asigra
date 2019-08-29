#!/bin/sh

USER="pgsql"
PG_CLIENT="/usr/local/bin/psql"
PG_HOST="/tmp"
DEST_DIR="/usr/local/ds-system"

echo "before starting postgres"
service dssystem status

echo "Starting Postgresql"
service postgresql start

echo "After postgres"
service dssystem status

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
echo "End of post upgrade"
service dssystem status
