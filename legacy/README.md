# Legacy

Configs that are no longer part of the daily setup but are kept for reference
and for the odd machine that still needs them. Nothing in here is linked by
`bin/quick_setup.sh` or checked by `bin/check.sh`.

## `vimrc`

The pre-Neovim setup (2020–2023): vim-plug, NERDTree, fzf.vim, airline, a
Python-oriented IDE layout. Superseded by [`nvim/`](../nvim/), which carries
the same ideas (space leader, NERDTree, tmux dispatch, One Dark) on native LSP
and Treesitter.

To use it on a box that only has classic Vim:

```bash
ln -s ~/myprojects/dotfiles/legacy/vimrc ~/.vimrc
vim +PlugInstall +qa
```

## `i3/`, `i3status/`

X11 window manager config from the Debian desktop days. Linux now runs
[Omarchy](https://omarchy.org) (Hyprland), themed via
[`.config/omarchy/themes/one-dark`](../.config/omarchy/themes/one-dark/).

Packages the i3 config expects on Debian/Ubuntu:

```bash
sudo apt-get install i3 i3status suckless-tools i3lock rofi \
                     arandr xbacklight alsa-utils pulseaudio \
                     gnome-sound-applet indicator-sound volumeicon-alsa
```

```bash
ln -s ~/myprojects/dotfiles/legacy/i3       ~/.config/i3
ln -s ~/myprojects/dotfiles/legacy/i3status ~/.config/i3status
```
