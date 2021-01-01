#!/bin/bash

/etc/init.d/cups start
sleep 3

/usr/sbin/lpadmin -p LBP5050 -P /usr/share/cups/model/CNCUPSLBP5050CAPTJ.ppd -v ccp://localhost:59687 -E
/usr/sbin/lpadmin -p LBP3100 -P /usr/share/cups/model/CNCUPSLBP3100CAPTJ.ppd -v ccp://localhost:59687 -E

/etc/init.d/cups restart
sleep 3

# Need to change lp device number
/usr/sbin/ccpdadmin -p LBP5050 -o /dev/usb/lp0
/usr/sbin/ccpdadmin -p LBP3100 -o /dev/usb/lp1

sleep 2
/etc/init.d/ccpd restart

exec watch "/etc/init.d/ccpd status"