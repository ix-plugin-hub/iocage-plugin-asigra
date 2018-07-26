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

main()
{
	echo 'Installing Asigra'
	#install_asigra
}

main;
