#!/bin/bash
#
# pifactory_prep_build.sh
#
# this script will be run inside the clean build environment (as root) to make it messy ;-)

apt-get update
apt-get upgrade -y

# install SSH server
#apt-get install openssh-server -y
# nope we do not do this anymore