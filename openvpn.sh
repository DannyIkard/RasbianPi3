#!/bin/bash
. ./SharedLib





Install(){
	Title "Install OpenVPN"
	printf "\n"
	if [[ ! -f /etc/apt/preferences.d/stretch.pref || ! -f /etc/apt/sources.list.d/stretch.list ]]; then
		EchoBold -n "Adding Stretch Repositories..."
sudo bash -c "cat << EOF > /etc/apt/preferences.d/jessie.pref
Package: *
Pin: release a=jessie
Pin-Priority: 900
EOF"

sudo bash -c "cat << EOF > /etc/apt/preferences.d/stretch.pref
Package: *
Pin: release a=stretch
Pin-Priority: 750
EOF"

sudo bash -c "cat << EOF > /etc/apt/sources.list.d/jessie.list
deb http://mirrordirector.raspbian.org/raspbian/ jessie main contrib non-free rpi
EOF"

sudo bash -c "cat << EOF > /etc/apt/sources.list.d/stretch.list
deb http://mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi
EOF"
		Status;
	fi;

	EchoBold "apt-get update"
	sudo apt-get update
	EchoBold "sudo apt-get install openvpn"
	sudo apt-get -y install openvpn -t stretch

	EchoBold "Creating server.conf..."
sudo bash -c "cat << EOF > /etc/openvpn/server.conf

EOF"
 
	gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf
	# Edit server.conf
	# edit /etc/sysctl.conf
	sudo apt-get install ufw
	# all that UFW stuff
	cp -r /usr/share/easy-rsa/ /etc/openvpn
	mkdir /etc/openvpn/easy-rsa/keys
	#nano /etc/openvpn/easy-rsa/vars
	cd /etc/openvpn/easy-rsa
	. ./vars
	./clean-all
	./build-ca
	#build ca and server key
	#BUILD-DH...  Copy to /etc/openvpn?
	cp /etc/openvpn/easy-rsa/keys/{server.crt,server.key,ca.crt} /etc/openvpn
	#build client keys
	#copy client.conf example to keys folder as client.ovpn
	#modify client.ovpn
	openvpn --genkey --secret ta.key
}


if [[ "$1" = "install" ]]; then
	Install
else
	echo "This is help text"
fi
exit 0


