#!/bin/bash
. ./SharedLib
clear


if [[ ! -f /etc/apt/preferences.d/stretch.pref || ! -f /etc/apt/sources.list.d/stretch.list ]]; then
	EchoBold "Adding Stretch Repositories..."
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
fi