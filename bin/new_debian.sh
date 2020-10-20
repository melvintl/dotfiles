apt update && apt install -y git
apt install -y openssh-server vim wget curl
# apt install -y python3-dev  python3-venv

# sudo apt-get install gvim
apt install -y  vim-gtk3
apt install -y exuberant-ctags ack-grep silversearcher-ag ripgrep

# apt install -y fzf 
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

apt install -y ncdu ranger tldr jq
wget https://github.com/sharkdp/bat/releases/download/v0.16.0/bat_0.16.0_amd64.deb
dpkg -i bat_0.16.0_amd64.deb
