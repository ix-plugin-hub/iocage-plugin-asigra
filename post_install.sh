#!/bin/sh

DSSYSTEM="dssystem-14.0.txz"
URL="https://builds.ixsystems.com/~john/asigra/Software/DS-System/FreeBSD"

fetch ${URL}/${DSSYSTEM}
if [ "$?" != "0" ]; then
	echo "ERROR: Failed fetching ${DSSYSTEM}"
	exit 1
fi

tar -zxvf ${DSSYSTEM} -C /
