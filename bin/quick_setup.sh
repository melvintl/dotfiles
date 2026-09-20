# mkdir -p ~/myprojects
# cd myprojects
# git clone https://github.com/melvintl/dotfiles.git

ln -s -f $(pwd)/.bashrc ~/.bashrc
ln -s -f $(pwd)/.tmux.conf ~/.tmux.conf
ln -s -f $(pwd)/.tmux.conf.local ~/.tmux.conf.local
ln -s -f $(pwd)/.vimrc ~/.vimrc
ln -s -f $(pwd)/bin/tmux-session  ~/.tmux-session 
ln -s -f $(pwd)/.gitconfig ~/.gitconfig
ln -s -f $(pwd)/.gitignore ~/.gitignore

mkdir -p ~/.config/yamllint/
cp ./.config/yamllint/config ~/.config/yamllint/

mkdir -p ~/.config/pgcli/
cp ./.config/pgcli/config ~/.config/pgcli/

# Link the file, not the directory: hunk keeps per-machine state.json next to its config
mkdir -p ~/.config/lazygit/ ~/.config/hunk/
ln -s -f $(pwd)/.config/lazygit/config.yml ~/.config/lazygit/config.yml
ln -s -f $(pwd)/.config/hunk/config.toml ~/.config/hunk/config.toml

# Hunk diff reviewer. Omarchy already ships it through mise
if ! command -v hunk >/dev/null; then
  if command -v mise >/dev/null; then
    mise use -g hunk
  else
    curl -fsSL https://hunk.dev/install.sh | sh
  fi
fi
