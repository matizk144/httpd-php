#!bin/bash
set -e
set -x
apt-get update

apt-get install -y php${php_version}-xdebug unzip patch git

apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*