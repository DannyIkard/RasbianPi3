#!/bin/bash


GetScreenWidth(){
  stty size 2>/dev/null | cut -d " " -f2
}

Separator(){
  if [ $1 ]; then local sepchar="$1"; else local sepchar=" "; fi
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  for x in $(seq 1 $cols); do
    echo -n "$sepchar"
  done && echo ""
}

EchoBold(){
  if [ "$1" = "-n" ]; then shift; echo -en "\033[1m$@\033[0m"; else echo -e "\033[1m$@\033[0m"; fi
}



EchoRed(){
  if [ "$1" = "-n" ]; then shift; echo -en "\033[1;31m$@\033[0m"; else echo -e "\033[1;31m$@\033[0m"; fi
}



EchoGreen(){
  if [ "$1" = "-n" ]; then shift; echo -en "\033[38;5;22;1m$@\033[0m"; else echo -e "\033[38;5;22;1m$@\033[0m"; fi
}

Title(){
  echo -en "\033[7;1m"
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  (( Spacer = cols - ${#1} ))
  (( Spacer = Spacer / 2 ))
  for x in $(seq 1 $Spacer); do
    echo -n " "
  done
  echo -en "$1"
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  for x in $(seq 1 $Spacer); do
    echo -n " "
  done && echo -n " "; echo -e "\033[0m"
}


Install(){
	Title "Install OpenVPN"
	printf "\n"


	if [[ $(dpkg-query -W -f='${Status}' openvpn 2>/dev/null | grep -c "ok installed") = "0" ]]; then
		EchoBold "apt-get update"
		sudo apt-get update
		EchoBold "sudo apt-get install openvpn"
		sudo apt-get -y install openvpn
	fi
}


if [[ "$1" = "install" ]]; then
	Install
else
	echo "This is help text"
fi
exit 0


