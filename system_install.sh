#!/bin/bash

sudo ()
{
    [[ $EUID = 0 ]] || set -- command sudo "$@"
    "$@"
}

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "user_install.sh ran at $(date) from $SCRIPT_DIR" >> $SCRIPT_DIR/install.log

if [ `which apt` ]; then
  
  # Add source for RCM
  wget https://thoughtbot.com/thoughtbot.asc && \
    sudo apt-key add - < thoughtbot.asc && \
    echo "deb https://apt.thoughtbot.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thoughtbot.list

  # Install RCM
  sudo apt-get update
  sudo apt-get install -o Dpkg::Options::="--force-confold" -yq rcm netcat zsh iproute2

elif [ `which apk` ]; then
   sudo apk add rcm zsh iproute2
elif [ `which yum` ]; then
  cd /etc/yum.repos.d/
  sudo curl -LO https://download.opensuse.org/repositories/utilities/15.5/utilities.repo

  cd ~

  sudo yum -y update && sudo yum -y install zsh rcm
else
   echo "UNKNOWN LINUX DISTRO"
   exit 1
fi