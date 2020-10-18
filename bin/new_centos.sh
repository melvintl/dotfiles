yum install wget curl
yum install vim-X11 
yum install -y https://dl.bintray.com/subchen/yum-repo/the_silver_searcher-2.1.0-1.el8.x86_64.rpm

# apt-get install exuberant-ctags ack-grep
# apt-get install fzf ripgrep

sh -c 'wget https://github.com/sharkdp/bat/releases/download/v0.16.0/bat-v0.16.0-x86_64-unknown-linux-musl.tar.gz -O - |tar -xvzf - -C /usr/local/bin && mv /usr/local/bin/bat-v0.16.0-x86_64-unknown-linux-musl/bat /usr/local/bin/bat'

