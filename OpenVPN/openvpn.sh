#!/bin/bash
. ../SharedLib
ScriptDir="$( cd "$( dirname "$BASH_SOURCE[0]}" )" && pwd )"

Install(){
	mkdir -p /dev/shm/OpenVPNInstall 2>/dev/null
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
	sleep .5

	if [[ $(dpkg-query -W -f='${Status}' openvpn 2>/dev/null | grep -c "ok installed") = "0" ]]; then
		EchoBold "apt-get update"
		sudo apt-get update
		EchoBold "sudo apt-get install openvpn"
		sudo apt-get -y install openvpn -t stretch
	fi
	if [[ $(dpkg-query -W -f='${Status}' ufw 2>/dev/null | grep -c "ok installed") = "0" ]]; then
		EchoBold "Installing ufw"
		sudo apt-get install ufw
	fi

	EchoBold "Copying server.conf to /etc/openvpn/server.conf"
	cp -f ./server.conf /etc/openvpn/server.conf
	sleep .5
 
	EchoBold "Editing sysctl.conf to allow ipv4 forwarding"
	cp -f /etc/sysctl.conf /etc/sysctl.conf.bk
	cat /etc/sysctl.conf | sed -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" > /etc/sysctl.conf
	sleep .5

	# TODO: DISABLE IPV6

	EchoBold "Setting up UFW"
	ufw allow 443/tcp
	ufw allow 5900/tcp
	if [ ! -f /etc/default/ufw.bk ]; then cp -f /etc/default/ufw /etc/default/ufw.bk; fi
	cat /etc/default/ufw | sed -e "s/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/" > /etc/default/ufw.new
	mv -f /etc/default/ufw.new /etc/default/ufw
	cp -f before.rules /etc/ufw/before.rules
	ufw enable
	sleep .5

	EchoBold "EasyRSA setup"
	rm -rf /etc/openvpn/easy-rsa 2>/dev/null
	sudo cp -r /usr/share/easy-rsa/ /etc/openvpn
	sudo mkdir /etc/openvpn/easy-rsa/keys
	sleep .5

	EchoBold "We will now open nano to edit the var file."
	EchoBold "Please edit the below vars to your preference:"
	read -e -p "KEY_COUNTRY=" -i "US" COUNTRY
	read -e -p "KEY_PROVINCE=" -i "CA" PROVINCE
	read -e -p "KEY_CITY=" -i "SanFrancisco" CITY
	read -e -p "KEY_ORG=" -i "Fort-Funston" ORG
	read -e -p "KEY_EMAIL=" -i "me@myhost.mydomain" EMAIL
	read -e -p "KEY_OU=" -i "MyOrganizationalUnit" OU

	EchoBold "Enter the number of clients that will use this VPN"
	CLIENTSOK=""
	while [[ $CLIENTSOK != "OK" ]]; do
		read -e -p "Client Keys=" -i "4" CLIENTS
		if [[ $CLIENTSOK =~ '^[0-9]+$' ]]; then
			if [[ $CLIENTS -gt 10 ]]; then
				EchoRed "Sanity Check:  A RaspberryPi may not be sufficient for"
				EchoRed "that number of clients.  Do you wish to continue?"
				read -e -p "Continue [y/n]=" -i "n" CLIENTSANITY
				if [[ "$CLIENTSANITY" == "y" ]]; then
					CLIENTSOK="OK"
				fi
			fi
			EchoRed "Please enter the number of client keys as a number"
		else
			CLIENTSOK="OK"
		fi
	done

	# Super-cumbersome copy and replace on vars file.  I'm really questioning why I'm doing this...
	TF="/dev/shm/OpenVPNInstall/vars"
	TTF="/dev/shm/OpenVPNInstall/vars.new"
	RF="/etc/openvpn/easy-rsa/vars"
	cp -r $RF $TF
	cat $TF | sed -e "s/export KEY_COUNTRY=\"US\"/export KEY_COUNTRY=\"$COUNTRY\"/" > $TTF; mv -f $TTF $TF
	cat $TF | sed -e "s/export KEY_PROVINCE=\"CA\"/export KEY_PROVINCE=\"$PROVINCE\"/" > $TTF; mv -f $TTF $TF
	cat $TF | sed -e "s/export KEY_CITY=\"SanFrancisco\"/export KEY_CITY=\"$CITY\"/" > $TTF; mv -f $TTF $TF
	cat $TF | sed -e "s/export KEY_ORG=\"Fort-Funston\"/export KEY_ORG=\"$ORG\"/" > $TTF; mv -f $TTF $TF
	cat $TF | sed -e "s/export KEY_EMAIL=\"me@myhost.mydomain\"/export KEY_EMAIL=\"$EMAIL\"/" > $TTF; mv -f $TTF $TF
	cat $TF | sed -e "s/export KEY_OU=\"MyOrganizationalUnit\"/export KEY_OU=\"$OU\"/" > $TTF; mv -f $TTF $TF
	mv -f $TF $RF

	EchoBold -n "Preparing easy-rsa directory"
	mkdir /etc/openvpn/easy-rsa/keys 2>/dev/null
	cd /etc/openvpn/easy-rsa
	source ./vars &>/dev/null
	./clean-all &>/dev/null
	Status
	sleep .5

	EchoBold -n "Building certificate authority"
	./build-ca --batch &>/dev/null
	Status
	sleep .5

	EchoBold -n "Building server key"
	./build-key-server --batch server &>/dev/null
	Status
	sleep .5

	EchoBold -n "Building TLS pre-shared key"
	openvpn --genkey --secret ta.key
	Status

	cp /etc/openvpn/easy-rsa/keys/{server.crt,server.key,ca.crt} /etc/openvpn

	i=0
	while [ $i -lt $CLIENTS ]; do
		let i=i+1
		EchoBold -n "Building key for client$i"
		./build-key --batch "client$i" &>/dev/null
		CO="/etc/openvpn/easy-rsa/keys/client$i.ovpn"
		cat $ScriptDir/client.conf > $CO
		echo "<ca>" >> $CO
		cat /etc/openvpn/easy-rsa/keys/ca.key >> $CO
		echo "</ca>" >> $CO
		echo "<cert>" >> $CO
		cat /etc/openvpn/easy-rsa/keys/client$i.crt >> $CO
		echo "</cert>" >> $CO
		echo "<key>" >> $CO
		cat /etc/openvpn/easy-rsa/keys/client$i.key >> $CO
		echo "</key>" >> $CO
		echo "key-direction 1" >> $CO
		echo "<tls-auth>" >> $CO
		cat /etc/openvpn/easy-rsa/ta.key >> $CO
		echo "</tls-auth>" >> $CO
		Status
	done

	./build-dh

	rm -rf /dev/shm/OpenVPNInstall 2>/dev/null
}


if [[ "$1" = "install" ]]; then
	Install
else
	Title "OpenVPN Wizard for RaspberryPi"
	printf "\n"
	EchoBold "Commands:"
	EchoBold "  install: Installs OpenVPN, UFW and configures both for use with Android devices"
	EchoBold "  addkey: Adds a key from the existing CA made with the install command"
fi
exit 0


