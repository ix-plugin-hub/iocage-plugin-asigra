#!/bin/sh


install_asigra()
{
	local dssystem="dssystem-14.0.txz"
	local url="https://builds.ixsystems.com/ix-iso/john/asigra/Software/DS-System/FreeBSD"

	fetch -v ${url}/${dssystem}
	if [ "$?" != "0" ]; then
	echo "ERROR: Failed fetching ${dssystem}"
	exit 1
	fi

	tar -zxvf ${dssystem} -C /
}

setup_inetd()
{
	sysrc -f /etc/rc.conf inetd_enable="YES"

	sed -i.bak -E 's/^#(echo[[:blank:]]+)/\1/g' /etc/inetd.conf
	sed -i.bak -E 's/^run_rc_command.+/run_rc_command "$1" -a $DBIP/g' /etc/rc.d/inetd

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

	service sendmail stop

	#sysrc -if /etc/rc.conf sshd_enable="YES"
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

	if grep -q '#listen_addresses' /usr/local/pgsql/data/postgresql.conf;
	then
		sed -i.bak '/listen_addresses/s/#//' /usr/local/pgsql/data/postgresql.conf
		sed -i.bak '/listen_addresses/s/localhost/*/' /usr/local/pgsql/data/postgresql.conf
	fi

	echo "host all all 127.0.0.0/24 trust" >> /usr/local/pgsql/data/pg_hba.conf

	service postgresql initdb
	service postgresql start
}

PG_main()
{
	echo 'Settings up /etc/make.conf'
	setup_make_conf

	echo 'Settings up /etc/rc.conf'
	setup_rc_conf

	echo 'Settings up /etc/sysctl.conf'
	setup_sysctl_conf

	echo 'Installing Asigra'
	#install_asigra

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

	echo Adding $(hostname) hostname to to hosts
	if ! grep -q "127.0.0.1 $(hostname)" /etc/hosts;
	then
		echo "127.0.0.1 $(hostname)" >> /etc/hosts
	fi

	sed -i.bak s/'group: compat'/'group: files ldap'/g ${nss_switch}
	sed -i.bak s/'passwd: compat'/'passwd: files ldap'/g ${nss_switch}

	echo -n "Setting up LDAP client..."
	echo "BASE      dc=cdpa,dc=com" > ${openldap_conf}
	echo "URI       ldap://127.0.0.1" >> ${openldap_conf}

	cp ${openldap_conf} ${etc_ldap_conf}

	echo "pam_login_attribute uid" >> ${etc_ldap_conf}
	cp ${openldap_conf} ${nss_ldap}

	chown root:wheel ${openldap_conf}
	chown root:wheel ${etc_ldap_conf}
	chown root:wheel ${nss_ldap}
	chown root:wheel ${nss_switch}
	chown root:wheel ${dss_pam}

	service nsswitch restart
}

# When PG and DS are different jails, this will do a lot of
# similar setup as PG_main() does. For now, just do what isn't
# done in PG_main().
DS_main()
{
}

main()
{
	PG_main
	DS_main
}

main;
