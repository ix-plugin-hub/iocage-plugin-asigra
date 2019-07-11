USER="pgsql"
PG_CLIENT="/usr/local/bin/psql"
PG_HOST="/tmp"
DEST_DIR="/usr/local/ds-system"

# Save the config values
echo "$DB" > /root/dbname
echo "$USER" > /root/dbuser
export LC_ALL=C
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 > /root/dbpassword
PASS=`cat /root/dbpassword`

# create user git
psql -d template1 -U pgsql -c "CREATE USER ${USER} CREATEDB SUPERUSER;"

# Set a password on the postgres account
psql -d template1 -U pgsql -c "ALTER USER ${USER} WITH PASSWORD '${PASS}';"

# Fix permission for postgres
echo "listen_addresses = '*'" >> /usr/local/pgsql/data/postgresql.conf
echo "host  all  all 0.0.0.0/0 md5" >> /usr/local/pgsql/data/pg_hba.conf

echo "Check for Database update"
                echo command: ${PG_CLIENT} -U ${USER} -h ${PG_HOST} -l -d template1
                if [ -z "`${PG_CLIENT} -U ${USER} -h ${PG_HOST} -l -d template1  | grep dssystem`"];then
                        echo there is no dssystem database found in the postgres database. Creating ...
                        ${PG_CLIENT} -U ${USER} -h ${PG_HOST} -c "create database dssystem" -d template1
                        ${PG_CLIENT} -U ${USER} -h ${PG_HOST} -f ${DEST_DIR}/db/postgresdssystem.sql -d dssystem
                        ${PG_CLIENT} -U ${USER} -h ${PG_HOST} -f ${DEST_DIR}/db/dssystem_locale_postgres.sql -d dssystem
                else
                        MAX=`for i in ${DEST_DIR}/db/dssp*.sql;do
                                echo ${i##*/}
                             done | sed -e "s/dssp//g" -e "s/.sql//g" | awk 'BEGIN{max=0}{if ($1 > max)max=$1}END{print max}'`
                        db_number=`${PG_CLIENT} -U ${USER} -h ${PG_HOST} -c "select db_number from ds_data" -d dssystem | sed -n "3p" | awk '{print $1}'`
                        if [ -n "`echo $db_number | grep -E '^-?[0-9][0-9]*$'`" ];then
                                if [ "`echo $db_number | grep -E -o '^-'`" == "-" ];then
                                        db_number=`echo $db_number | sed "s/^-//g"`
                                fi
                        fi
                        db_number=`expr $db_number + 1`
                        while [ $MAX -ge $db_number ];do
                                ${PG_CLIENT} -U ${USER} -h ${PG_HOST} -f ${DEST_DIR}/db/dssp${db_number}.sql -d dssystem
                                echo apply the patch dssp${db_number}.sql
                                db_number=`expr $db_number + 1`
                        done
                fi
