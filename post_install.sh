#!/bin/sh
# Enable the service
sysrc -f /etc/rc.conf inetd_enable="YES"
sysrc -f /etc/rc.conf nsswitch_enable="YES"
sysrc -f /etc/rc.conf postgresql_enable="YES"
sysrc -f /etc/rc.conf postgresql_user="pgsql"
sysrc -f /etc/rc.conf postgresql_data="/usr/local/pgsql/data"
sysrc -f /etc/rc.conf nginx_enable="YES"
sysrc -f /etc/rc.conf dssystem_enable="YES"

sed -i.bak -E 's/^#(echo[[:blank:]]+)/\1/g' /etc/inetd.conf
sed -i.bak -E 's/^run_rc_command.+/run_rc_command "$1" -a $DBIP/g' /etc/rc.d/inetd
rm -f /etc/rc.d/inetd.bak
service inetd start

#dsystems is looking for user/group pgsql
pw groupadd -q -n pgsql
echo -n 'pgsql' | pw useradd -n pgsql -u 1001 -s /bin/sh -m -d /usr/local/pgsql -g pgsql -G wheel -c 'Database User' -H 0

# Start the service
service postgresql initdb
service postgresql start

USER="pgsql"

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

# Restart postgresql after config change
service postgresql restart

Echo "Figure out our Network IP"
#Very Dirty Hack to get the ip for dhcp, the problem is that IOCAGE_PLUGIN_IP doesent work on DCHP clients
#cat /var/db/dhclient.leases* | grep fixed-address | uniq | cut -d " " -f4 | cut -d ";" -f1 > /root/dhcpip
netstat -nr | grep lo0 | awk '{print $1}' | uniq | cut -d " " -f4 | cut -d ";" -f1 > /root/dhcpip
#netstat -nr | grep lo0 | awk '{print $1}' > /root/dhcpip 
#sed -i.bak '2,$d' /root/dhcpip 
IP=`cat /root/dhcpip`
#rm /root/dhcpip.bak

echo "Set root password..."
echo -n 'root' | pw usermod root -m -h 0

echo "Set Hostname..."
echo "127.0.0.1 $(hostname)" >> /etc/hosts

echo "Setup LDAP.."
echo "BASE      dc=cdpa,dc=com" > /usr/local/etc/openldap/ldap.conf
echo "URI       ldap://$IP" >> /usr/local/etc/openldap/ldap.conf
cp  /usr/local/etc/openldap/ldap.conf /usr/local/etc/ldap.conf
echo "pam_login_attribute uid" >> /usr/local/etc/ldap.conf
cp  /usr/local/etc/openldap/ldap.conf /etc/nsswitch.conf

echo "Setup DB Username"
sed -i '' "s|pg_user=|pg_user=${USER}|g" /root/dssystem_install.ini
echo "Setup DB Password"
sed -i '' "s|pg_pass=|pg_pass=${PASS}|g" /root/dssystem_install.ini

echo "Creating /zdata/Upgrade directory"
mkdir -p /zdata/Upgrade

echo "Fix Libc"
ln -fs /lib/libc.so.7 /usr/local/lib/libdl.so.1

echo "Download Distfiles"
cd /root
fetch https://asigra-f611.kxcdn.com/14.1/latest/DS-Operator.zip
fetch https://asigra-f611.kxcdn.com/14.1/latest/dssystem-14.1.txz

echo "Install dssystem"
pkg add  /root/dssystem-14.1.txz

echo "Prepare DS Operator"
mkdir -p /usr/local/www/asigra
unzip DS-Operator.zip -d /usr/local/www/asigra

sed -i.bak -E "s|codebase=\"(.+)\"|codebase=\"http://$IP/asigra/\"|" /usr/local/www/asigra/DSOP.jnlp
rm -f /usr/local/www/asigra/DSOP.jnlp.bak

#make sure we have all services started
echo "Restart inetd ..."
/etc/rc.d/inetd restart
echo "Restart nsswitch ..."
/etc/rc.d/nsswitch restart
echo "Restart dssystem..."
/usr/local/etc/rc.d/dssystem restart
echo "Restart nginx..."
/usr/local/etc/rc.d/nginx restart
