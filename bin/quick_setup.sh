mkdir -f ~/myprojects
cd myprojects
git clone https://github.com/melvintl/dotfiles.git
ln -s -f ~/myprojects/dotfiles/.tmux.conf ~/.tmux.conf
ln -s -f ~/myprojects/dotfiles/.tmux.conf.local ~/.tmux.conf.local
ln -s -f ~/myprojects/dotfiles/.vimrc ~/.vimrc
ln -s -f ~/myprojects/dotfiles/bin/tmux-session  ~/.tmux-session 

