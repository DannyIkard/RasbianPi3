#!/bin/bash



GetScreenWidth(){
  stty size 2>/dev/null | cut -d " " -f2
}


Status(){
  local check=$?
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  local scol=$(($cols - 7))
    if [ $check = 0 ]; then
      if [ "$1" = "Success" ]; then Success=1; fi
      echo -e "\033[${scol}G\033[38;5;22;1mOK\033[0;39m"
    else
      if [ $@ ]; then
        if [ "$1" = "Success" ]; then
          Success=0
        else
          $@
        fi
      else
        echo -e "\033[${scol}G\033[1;31mError\033[0;39m"
      fi
    fi
}



StatusOK(){
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  local scol=$(($cols - 7))
  echo -e "\033[1A\033[${scol}G\033[38;5;22;1mOK\033[0;39m"
}



StatusError(){
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  local scol=$(($cols - 7))
  echo -e "\033[1A\033[${scol}G\033[1;31mError\033[0;39m"
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
  done && echo -e "\033[0m"
}



Longline(){
  cols=$(GetScreenWidth); [ "$cols" ] || cols=80
  echo -e "$@" | fold -sw$cols
}



AddIfDoesntExist(){
  if ! cat $2 | grep "$1"; then
    sudo su -c "echo \"$1\">>$2" root
  fi
}



SudoWriteLineIfNotThere() {
  su -c "grep -q -F '$1' $2 || echo '$1' >> $2" root
}



SudoRequired(){
  if ! command -v sudo >/dev/null; then
    EchoRed "  Please install sudo to use this script."
    EchoBold "`Longline  'As root, do \"apt-get install sudo\" then \"adduser <username> sudo\" and then log out and log back in.'`"
    exit 1
  fi
  clear
  EchoRed "This script requires sudo."
  echo -n "Enter the "
  sudo printf ""
  clear
}



Success="0"
JustFail="0"
Exit(){
  if [ "$JustFail" = "0" ]; then
    JustFail="1"
    if [ "$Success" = "1" ]; then
      if [ "$2" != "NoPrompt" ]; then
        EchoGreen "  Press enter to exit..."
        read LINE
        exit 0
      fi
    else
      EchoRed "  Script failure."
      Longline "  $1"
      EchoBold -n "  Press enter to exit..."
      read LINE
      exit 1
    fi
  fi
}



SuccessExit(){
  if [ $? = 0 ]; then Success="1"; fi
  exit 0
}


clear
Title "==== Android OpenVPN Wizard ===="
printf "\n"

printf "\n"; Separator "_"; EchoBold -n "  Installing OpenVPN - "; echo "apt-get update"
sudo apt-get update

printf "\n"; Separator "_"; EchoBold -n "  Installing OpenVPN - "; echo "apt-get install openvpn"
sudo apt-get install openvpn









