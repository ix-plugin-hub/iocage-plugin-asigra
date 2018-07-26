#!/bin/sh

DSSYSTEM="dssystem-14.0.txz"
URL="https://builds.ixsystems.com/ix-iso/john/asigra/Software/DS-System/FreeBSD"
URL="http://12.189.233.133/ix-iso/john/asigra/Software/DS-System/FreeBSD"

fetch -v ${URL}/${DSSYSTEM}
if [ "$?" != "0" ]; then
	echo "ERROR: Failed fetching ${DSSYSTEM}"
	exit 1
fi

tar -zxvf ${DSSYSTEM} -C /
