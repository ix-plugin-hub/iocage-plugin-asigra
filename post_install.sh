#!/bin/sh

setup_inetd()
{
	sysrc -f /etc/rc.conf inetd_enable="YES"

	sed -i.bak -E 's/^#(echo[[:blank:]]+)/\1/g' /etc/inetd.conf
	sed -i.bak -E 's/^run_rc_command.+/run_rc_command "$1" -a $DBIP/g' /etc/rc.d/inetd
	rm -f /etc/rc.d/inetd.bak

	service inetd start
}

setup_rc_conf()
{
	sysrc -if /etc/rc.conf network_interfaces=""
	sysrc -if /etc/rc.conf rpcbind_enable="NO"
	sysrc -if /etc/rc.conf cron_flags="$cron_flags -J 15"
	sysrc -if /etc/rc.conf syslogd_flags="-ss"

	sysrc -if /etc/rc.conf sendmail_enable="NO"
	sysrc -if /etc/rc.conf sendmail_submit_enable="NO"
	sysrc -if /etc/rc.conf sendmail_outbound_enable="NO"
	sysrc -if /etc/rc.conf sendmail_msp_queue_enable="NO"

	service sendmail onestop > /dev/null 2>&1

}

setup_ssh()
{
	# Enable SSH
	sysrc -if /etc/rc.conf sshd_enable="YES"

	# Enable root login
	sed -i '' 's|#PermitRootLogin no|PermitRootLogin yes|g' /etc/ssh/sshd_config

	# Do the host key gen
	service sshd keygen

	# Start the sshd service on first install
	service sshd start
}

setup_make_conf()
{
	cat <<-__EOF__>> /etc/make.conf
	KDIRPREFIX=    /var/ports
	DISTDIR=       /var/ports/distfiles
	PACKAGES=      /var/ports/packages
	INDEXDIR=      /var/ports
__EOF__
}

setup_sysctl_conf()
{
	cat <<-__EOF__ >> /etc/sysctl.conf
	security.jail.sysvipc_allowed=1
	security.jail.allow_raw_sockets=1
__EOF__
}

setup_postgresql()
{
	sysrc -if /etc/rc.conf postgresql_enable="YES"
	sysrc -if /etc/rc.conf postgresql_data="/usr/local/pgsql/data"
	sysrc -if /etc/rc.conf postgresql_user="pgsql"

	pw groupdel -q -n postgres
	pw userdel -q -n postgres

	pw groupadd -q -n pgsql
	echo -n 'pgsql' | pw useradd -n pgsql -u 1001 -s /bin/sh -m \
		-d /usr/local/pgsql -g pgsql -G wheel -c 'Database User' -H 0

	service postgresql initdb

	chown -R pgsql:pgsql /usr/local/pgsql

	if grep -q '#listen_addresses' /usr/local/pgsql/data/postgresql.conf;
	then
		sed -i.bak '/listen_addresses/s/#//' /usr/local/pgsql/data/postgresql.conf
		sed -i.bak '/listen_addresses/s/localhost/*/' /usr/local/pgsql/data/postgresql.conf
		rm -f /usr/local/pgsql/data/postgresql.conf.bak
	fi

	echo "host all all 127.0.0.0/24 trust" >> /usr/local/pgsql/data/pg_hba.conf
	echo "host all all ${IOCAGE_PLUGIN_IP}/24 trust" >> /usr/local/pgsql/data/pg_hba.conf

	service postgresql start
}

PG_main()
{
	echo 'Settings up /etc/make.conf'
	setup_make_conf

	echo 'Settings up /etc/rc.conf'
	setup_rc_conf

	echo "Setting up SSH"
	setup_ssh

	echo 'Settings up /etc/sysctl.conf'
	setup_sysctl_conf

	echo 'Settings up Inetd'
	setup_inetd

	echo 'Setting up PostgreSQL'
	setup_postgresql
}

setup_ldap()
{
	local openldap_conf=/usr/local/etc/openldap/ldap.conf
	local etc_ldap_conf=/usr/local/etc/ldap.conf
	local nss_ldap=/usr/local/etc/nss_ldap.conf
	local nss_switch=/etc/nsswitch.conf
	local dss_pam=/usr/local/etc/pam.d/dssystem

	echo "Adding $(hostname) hostname to to hosts"
	if ! grep -q "127.0.0.1 $(hostname)" /etc/hosts;
	then
		echo "127.0.0.1 $(hostname)" >> /etc/hosts
	fi

	# XXX Skip this for now since it isn't configured XXX
	#sed -i.bak -E s/'^group: compat'/'group: files ldap'/g "${nss_switch}"
	#sed -i.bak -E s/'^passwd: compat'/'passwd: files ldap'/g "${nss_switch}"
	#rm -f "${nss_switch}.bak"

	echo -n "Setting up LDAP client..."
	echo "BASE      dc=cdpa,dc=com" > "${openldap_conf}"
	echo "URI       ldap://${IOCAGE_PLUGIN_IP}" >> "${openldap_conf}"

	cp "${openldap_conf}" "${etc_ldap_conf}"

	echo "pam_login_attribute uid" >> "${etc_ldap_conf}"
	cp "${openldap_conf}" "${nss_ldap}"

	chown root:wheel "${openldap_conf}"
	chown root:wheel "${etc_ldap_conf}"
	chown root:wheel "${nss_ldap}"
	chown root:wheel "${nss_switch}"
	chown root:wheel "${dss_pam}"

	service nsswitch restart
}

setup_asigra()
{
	local dssystem="dssystem-14.0.0.1.txz"
	local url="http://builds.ixsystems.com/ix-iso/john"

	cd /root

	fetch -v "${url}/${dssystem}"
	if [ "$?" != "0" ]; then
		echo "ERROR: Failed fetching ${dssystem}"
		exit 1
	fi

	# In the 2 jail configuration, this is a host dataset shared by the 2 jails
	mkdir /zdata

	pkg add --force "${dssystem}"

	service dssystem start
}

setup_nginx()
{
	local dsoperator="DS-Operator_FreeBSD_14_0_0_1.zip"
	local url="http://12.189.233.133/ix-iso/john"
	local wwwpath="/usr/local/www/asigra"
	local ip="$(echo "${IOCAGE_PLUGIN_IP}"|cut -f1 -d,)"

	cd /root

	fetch -v "${url}/${dsoperator}"
	if [ "$?" != "0" ]; then
		echo "ERROR: Failed fetching ${dsoperator}"
		exit 1
	fi

	mkdir -p "${wwwpath}"
	unzip "${dsoperator}" -d "${wwwpath}"
	sed -i.bak -E "s|codebase=\"(.+)\"|codebase=\"http://$ip/asigra/\"|" /usr/local/www/asigra/DSOP.jnlp
	rm -f /usr/local/www/asigra/DSOP.jnlp.bak

	# Setup landing page
	sed -i '' "s|/usr/local/www/nginx;|/usr/local/www/asigra-landing;|g" /usr/local/etc/nginx/nginx.conf

	sysrc -f /etc/rc.conf nginx_enable="YES"

	service nginx start
}

fix_etc_hosts()
{
	sed -i.bak -E 's/^([0-9.]+),.+[[:space:]]+(.+)/\1 \2/' /etc/hosts
	rm -f /etc/hosts.bak
}

set_root_password()
{
	echo -n 'root' | pw usermod root -m -h 0
}

setup_local_dirs()
{
	echo "Creating /zdata/Upgrade directory"
	mkdir /zdata/Upgrade
}

# When PG and DS are different jails, this will do a lot of
# similar setup as PG_main() does. For now, just do what isn't
# done in PG_main().
DS_main()
{
	echo 'Fixing up hosts file cuz Brandon'
	fix_etc_hosts

	echo 'Setting up LDAP'
	setup_ldap

	echo 'Setting up Asigra'
	setup_asigra

	echo 'Settings up Nginx'
	setup_nginx

	echo 'Setting root password'
	set_root_password

	echo 'Setting up libdl.so.1 link'
	setup_libdl

	echo 'Setting up local dirs'
	setup_local_dirs
}

setup_libdl()
{
	ln -fs /lib/libc.so.7 /usr/local/lib/libdl.so.1
}

main()
{
	PG_main
	DS_main
}

main;
