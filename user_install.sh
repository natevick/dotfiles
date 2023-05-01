#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "user_install.sh ran at $(date) from $SCRIPT_DIR" >> $SCRIPT_DIR/install.log

echo "Installing fzf" >> ~/install.log
# Install fzf from source
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && \
  ~/.fzf/install --all

echo "Installing oh my zsh if it does not exist" >> ~/install.log

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
echo "Installing dotfiles with rcup" >> ~/install.log

rcup -d $SCRIPT_DIR -f -B docker tmux.conf zshrc gitconfig

echo "Installing solargraph" >> ~/install.log
gem install solargraph