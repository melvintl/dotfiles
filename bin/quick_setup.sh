# mkdir -p ~/myprojects
# cd myprojects
# git clone https://github.com/melvintl/dotfiles.git

ln -s -f $(pwd)/.tmux.conf ~/.tmux.conf
ln -s -f $(pwd)/.tmux.conf.local ~/.tmux.conf.local
ln -s -f $(pwd)/.vimrc ~/.vimrc
ln -s -f $(pwd)/bin/tmux-session  ~/.tmux-session 

mkdir -p ~/.config/yamllint/
cp ./config/yamllint/config ~/.config/yamllint/

mkdir -p ~/.config/pgcli/
cp ./config/pgcli/config ~/.config/pgcli/
