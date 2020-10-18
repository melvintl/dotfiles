# mkdir -p ~/myprojects
# cd myprojects
# git clone https://github.com/melvintl/dotfiles.git
ln -s -f $(pwd)/.tmux.conf ~/.tmux.conf
ln -s -f $(pwd)/.tmux.conf.local ~/.tmux.conf.local
ln -s -f $(pwd)/.vimrc ~/.vimrc
ln -s -f $(pwd)/bin/tmux-session  ~/.tmux-session 

