# Setup

## Point to NeoVim setup
- Need the latest version of Neovim(may not be able to get 10.1+ via apt install)
- `mkdir -p {~/.config/}`
- `cd ~/config && ln -s ~/myprojects/dotfiles/nvim nvim`


## Other binaries that are required

```bash
# LazyVim will install via build so has other binary dependency 
sudo apt install make build-essential

# Search utils:
sudo apt install fzf
sudo apt install ripgrep silversearcher-ag

# Others:
sudo apt install direnv
```

## Language servers

### To setup jedi server:

```bash
python3 -m pip install --user pipx
# python3 -m pip install --user pipx --break-system-packages
python3 -m pipx ensurepath
pipx install jedi-language-server
```

### To setup TypeScript language server:

```bash
# Install TypeScript language server
npm install -g typescript typescript-language-server

# Install ESLint for linting
npm install -g eslint

# Install Prettier for formatting
npm install -g prettier
```

See `docs/typescript-setup.md` for more detailed TypeScript setup instructions.

## Fonts

Install patched nerd fonts (eg JetBrans Mono) on the terminal 
Change the below in the `lua/plugins/look_n_feel.lua` file if you dont want to show icons
```lua
        icons_enabled = false,
```
