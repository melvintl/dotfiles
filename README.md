# dotfiles
Repo contains the dotfiles I mostly use.

## Vim
(Note: the below is only for Vim and not for the Neovim setup) 
Plugins have minimal external depenencies except for the below:

### MacOS
```
brew install ctags
brew install ag fzf ripgrep
```

### Debian
```
apt-get install gvim

sudo apt-get install exuberant-ctags ack-grep
sudo apt-get install silversearcher-ag
```

## i3

### Debian:
```
sudo apt-get install i3 i3status suckless-tools i3lock rofi
sudo apt-get install arandr
sudo apt-get install xbacklight alsa-utils pulseaudio
sudo apt-get install gnome-sound-applet indicator-sound
sudo apt-get install volumeicon-alsa
```

Other Install(debian):
```
apt install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
https://github.com/chriskempson/base16-shell



Other utils
```
#CSV Viewer
apt install visidata
```


Notes:
- On Windows install:
 - Windows Terminal
     - Install `JetBrainsMono Nerd Font Mono` patched font
     - Set theme to `One Half Dark`
     - Latest terminal version and Unbuntu 24+ takes care of clipboard without any other dependencies
 
