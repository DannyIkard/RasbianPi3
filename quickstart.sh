#!/bin/bash
. ./SharedLib
clear

Title "QuickStart - Update"
apt-get update
clear

Title "QuickStart"
EchoBold "Install fandaemon"
cp FanController.sh /usr/sbin/fandaemon
EchoRed "Now edit crontab for /usr/sbin/fandaemon"
sleep 5
crontab -e
clear

Title "QuickStart - anything-sync-daemon"
apt-get install build-essential checkinstall rsync
rm -rf anything-sync-daemon 2>/dev/null
git clone https://github.com/graysky2/anything-sync-daemon.git
cd anything-sync-daemon/ && git checkout v5.85
make && checkinstall --pkgversion 5.85 make install-systemd-all
clear
Title "Quickstart - anything-sync-daemon"
EchoRed "Edit WHATTOSYNC to preference and VOLATILE="/dev/shm"
nano /etc/asd.conf
systemctl enable asd.service && service asd restart
clear

Title "QuickStart - Upgrade"
clear
apt-get upgrade
EchoRed "Restarting in 10 seconds..."
reboot