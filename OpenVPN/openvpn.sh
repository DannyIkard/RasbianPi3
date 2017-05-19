#!/bin/bash
. ../SharedLib

# TODO: DISABLE IPV6, choose port/tcp,udp, harden...

ScriptDir="$( cd "$( dirname "$BASH_SOURCE[0]}" )" && pwd )"

if [[ $EUID -ne 0 ]]; then
	EchoRed "This script must be run as root"
	exit 1
fi

EnableKeysSharing(){
	EchoBold -n "Starting sshd"
	systemctl start ssh.service
	Status

	EchoBold -n "Starting vnc"
	systemctl start vncserver-x11-serviced.service
	Status

	EchoBold -n "Opening firewall for ssh and vnc"
	ufw allow 22 &>/dev/null
	ufw allow 5900 &>/dev/null
	Status
	
	EchoGreen "Remote Access Enabled"
}

DisableKeysSharing(){
	EchoBold -n "Closing firewall for ssh and vnc"
	ufw deny 22 &>/dev/null
	ufw deny 5900 &>/dev/null
	Status

	EchoBold -n "Stopping sshd"
	systemctl stop ssh.service
	Status

	EchoBold -n "Stopping vnc"
	systemctl stop vncserver-x11-serviced.service
	Status
	
	EchoGreen "Remote Access Disabled"
}


Install(){
	clear
	Title "Install OpenVPN"
	SHMDIR="/dev/shm/OpenVPNInstall"
	mkdir -p $SHMDIR 2>/dev/null
	if [ -d /etc/openvpn/easy-rsa/ ]; then
		EchoRed -n "Removing existing easy-rsa directory in /etc/openvpn"
		sudo rm -rf /etc/openvpn/easy-rsa
		Status
	fi
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


	if [[ $(dpkg-query -W -f='${Status}' openvpn 2>/dev/null | grep -c "ok installed") = "0" ]]; then
		EchoBold "apt-get update"
		apt-get update
		EchoBold "sudo apt-get install openvpn"
		apt-get -y install openvpn -t stretch
	fi
	if [[ $(dpkg-query -W -f='${Status}' ufw 2>/dev/null | grep -c "ok installed") = "0" ]]; then
		EchoBold "Installing ufw"
		apt-get install ufw
	fi

	Separator
	EchoBold "--Enter the IP or dynamic domain address of this server"
	read -e -p "Server Address=" -i "" SERVERIP

	EchoBold -n "Copying server.conf to /etc/openvpn/server.conf"
	cp $ScriptDir/server.conf /etc/openvpn/server.conf
	Status

	EchoBold -n "Editing sysctl.conf to allow ipv4 forwarding"
	cp -f /etc/sysctl.conf /etc/sysctl.conf.bk
	ReplaceLineIfExists "/etc/sysctl.conf" "#net.ipv4.ip_forward=1" "net.ipv4.ip_forward=1"
	Status

	EchoBold -n "Setting up UFW - allow 443/tcp"
	ufw allow 443/tcp &>/dev/null
	Status

	EchoBold -n "Setting up UFW - allow 22/tcp"
	ufw allow 22/tcp &>/dev/null
	Status

	EchoBold -n "Setting up UFW - allow 5900/tcp"
	ufw allow 5900/tcp &>/dev/null
	Status
	
	EchoBold -n "Editing /etc/default/ufw"
	if [ ! -f /etc/default/ufw.bk ]; then sudo cp -f /etc/default/ufw /etc/default/ufw.bk; fi
	cat /etc/default/ufw | sed -e "s/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/" > /etc/default/ufw.new
	mv -f /etc/default/ufw.new /etc/default/ufw
	Status

	EchoBold -n "Editing /etc/ufw/before.rules"
	cp -f /etc/ufw/before.rules /etc/ufw/before.rules.bk
	cat <<- EOF > $SHMDIR/before.rules
	# OpenVPN rules
	*nat
	:POSTROUTING ACCEPT [0:0]
	-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE
	COMMIT
	EOF
	cat /etc/ufw/before.rules >> $SHMDIR/before.rules
	mv -f $SHMDIR/before.rules /etc/ufw/before.rules
	Status

	EchoBold -n "Enabling UFW"
	ufw enable &>/dev/null
	Status

	EchoBold "EasyRSA setup"
	rm -rf /etc/openvpn/easy-rsa 2>/dev/null
	cp -r /usr/share/easy-rsa/ /etc/openvpn
	mkdir /etc/openvpn/easy-rsa/keys

	Separator "_"
	EchoBold "We will now open nano to edit the var file."
	EchoBold "--Please edit the below vars to your preference:"
	read -e -p "KEY_COUNTRY=" -i "US" COUNTRY
	read -e -p "KEY_PROVINCE=" -i "CA" PROVINCE
	read -e -p "KEY_CITY=" -i "SanFrancisco" CITY
	read -e -p "KEY_ORG=" -i "Fort-Funston" ORG
	read -e -p "KEY_EMAIL=" -i "me@myhost.mydomain" EMAIL
	read -e -p "KEY_OU=" -i "MyOrganizationalUnit" OU

	Separator "_"
	EchoBold "--Enter the number of clients that will use this VPN"
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

	EchoBold -n "Adding ovpnkeys group"
	groupadd ovpnkeys &>/dev/null
	Status


#--/etc/ssh/sshd_config
	EchoBold -n "Backing up /etc/ssh/sshd_config to sshd_config.bk"
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bk
	Status

	if cat /etc/ssh/sshd_config | grep "Subsystem sftp /usr/lib/openssh/sftp-server" 1>/dev/null; then
		EchoBold -n "Modifying /etc/ssh/sshd_config for chrooted sftp group ovpnkeys"
		ReplaceLineIfExists "/etc/ssh/sshd_config" "Subsystem sftp /usr/lib/openssh/sftp-server" "Subsystem sftp internal-sftp"
		Status
	fi

	if ! cat /etc/ssh/sshd_config | grep "Match Group ovpnkeys" 1>/dev/null; then
		EchoBold -n "Adding ovpnkeys group restriction to sshd_config"
		echo "" >>/etc/ssh/sshd_config
		echo "Match Group ovpnkeys" >>/etc/ssh/sshd_config
		echo "	ChrootDirectory /home/%u" >>/etc/ssh/sshd_config
		echo "	X11Forwarding no" >>/etc/ssh/sshd_config
		echo "	AllowTcpForwarding no" >>/etc/ssh/sshd_config
		echo "	ForceCommand internal-sftp" >>/etc/ssh/sshd_config
		Status
	fi

	EchoBold -n "Creating vars file"
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/vars" "export KEY_COUNTRY=\"US\"" "export KEY_COUNTRY=\"$COUNTRY\""
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/vars" "export KEY_PROVINCE=\"CA\"" "export KEY_PROVINCE=\"$PROVINCE\""
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/vars" "export KEY_CITY=\"SanFrancisco\"" "export KEY_CITY=\"$CITY\""
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/vars" "export KEY_ORG=\"Fort-Funston\"" "export KEY_ORG=\"$ORG\""
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/vars" "export KEY_EMAIL=\"me@myhost.mydomain\"" "export KEY_EMAIL=\"$EMAIL\""
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/vars" "export KEY_OU=\"MyOrganizationalUnit\"" "export KEY_OU=\"$OU\""
	Status

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

	#gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > $SHMDIR/server.conf
	#ReplaceLineIfExists "$SHMDIR/server.conf" "port 1194" "port 443"
	#ReplaceLineIfExists "$SHMDIR/server.conf" ";proto tcp" "proto tcp"
	#ReplaceLineIfExists "$SHMDIR/server.conf" "proto udp" ";proto udp"
	#ReplaceLineIfExists "$SHMDIR/server.conf" "dh dh2048.pem" "dh dh$KEYSTRENGTH.pem"
	#ReplaceLineIfExists "$SHMDIR/server.conf" ";topology subnet" "topology subnet"
	#ReplaceLineIfExists "$SHMDIR/server.conf" ";push \"dhcp-option DNS 208.67.222.222\"" "push \"dhcp-option DNS 192.168.1.1"
	#ReplaceLineIfExists "$SHMDIR/server.conf" ";push \"dhcp-option DNS 208.67.222.220\"" "push \"dhcp-option DNS 8.8.8.8"
	#TODO: Get KEYSTRENGTH input, DNS input, LAN input for server.conf.  Add line to push extra DNS options down the list beyond the two commented options
	#TODO: client2client?  Cryptocipher?
	#ipp.txt in /dev/shm to reduce writes?

	EchoBold -n "Copying client.conf to /etc/openvpn/easy-rsa/keys/client.conf"
	cp $ScriptDir/client.conf /etc/openvpn/easy-rsa/keys/client.conf
	ReplaceLineIfExists "/etc/openvpn/easy-rsa/keys/client.conf" "remote my-server-1 443" "remote $SERVERIP 443"
	Status

	#Do the same as above for client.conf
	#cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf


	i=0
	while [ $i -lt $CLIENTS ]; do
		let i=i+1
		EchoBold -n "Building key for client$i"
		./build-key --batch "client$i" &>/dev/null
		CO="/etc/openvpn/easy-rsa/keys/client$i.ovpn"
		cat /etc/openvpn/easy-rsa/keys/client.conf > $CO
		echo "<ca>" >> $CO
		cat /etc/openvpn/easy-rsa/keys/ca.crt >> $CO
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
		Separator "_"
		EchoBold "--Create user for SFTP key retrieval"
		adduser client$i
		usermod client$i -g ovpnkeys
		usermod client$i -s /bin/false
		mkdir -p /home/client$i/ovpnkeys
		chown root:root /home/client$i
		chmod 755 /home/client$i
		chown client$i:ovpnkeys /home/client$i/ovpnkeys
		chmod 500 /home/client$i/ovpnkeys
		usermod client$i -d /ovpnkeys
		cp $CO /home/client$i/ovpnkeys/client$i.ovpn
		chown -R client$i:ovpnkeys /home/client$i/ovpnkeys
		chmod 444 /home/client$i/ovpnkeys/client$i.ovpn
	done
	
	Separator "_"
	./build-dh
	Separator "_"

	EchoBold -n "Copying ta.key and dh2048.pem to /etc/openvpn"
	cp /etc/openvpn/easy-rsa/ta.key /etc/openvpn
	cp /etc/openvpn/easy-rsa/keys/dh2048.pem /etc/openvpn
	Status

	EchoBold -n "Enable openvpn@server.service"
	systemctl enable openvpn@server.service
	Status
	rm -rf $SHMDIR 2>/dev/null
}


if [[ "$1" == "install" ]]; then
	Install
elif [[ "$1" == "startra" ]]; then
	EnableKeysSharing
elif [[ "$1" == "stopra" ]]; then
	DisableKeysSharing
else
	Title "OpenVPN Wizard for RaspberryPi"
	Separator "_"
	EchoBold "Commands:"
	EchoBold "  install: "; echo "Installs OpenVPN, UFW and configures both for use with Android devices"
	EchoBold "  startra: "; echo "Starts sshd and vncserver and opens firewall"
	EchoBold "  stopra: "; echo "Stops sshd and vncserver and closes firewall"
	Separator
fi
exit 0
