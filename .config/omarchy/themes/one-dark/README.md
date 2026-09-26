# One Dark (Omarchy theme)

An [Omarchy](https://omarchy.org/) theme that matches the rest of this repo:
the [`onedark.nvim`](https://github.com/navarasu/onedark.nvim) palette used by
`nvim/lua/plugins/look_n_feel.lua`, and the One Dark colours already hand-set in
`.tmux.conf` (the `bg`/`fg`/`yellow` variables in its theme section). The accent is One Dark
yellow `#e5c07b` rather than the more usual blue, so Hyprland's active window
border and the bar match the tmux status line.

Everything Omarchy themes — Hyprland borders, the shell/bar, Alacritty, foot,
kitty, ghostty, btop, helix, chromium, Obsidian, the VS Code theme JSON — is
generated from `colors.toml` via the templates in
`/usr/share/omarchy/default/themed/*.tpl`. Only the four files below are
hand-written.

| File | Purpose |
| --- | --- |
| `colors.toml` | The palette. Everything else derives from it. |
| `neovim.lua` | LazyVim spec pinning `onedark.nvim` as the colorscheme. |
| `icons.theme` | GTK icon theme (`Yaru-yellow`, to match the yellow accent). |
| `vscode.json` | VS Code extension + theme name (One Dark Pro Darker). |
| `backgrounds/` | Wallpapers; cycle with `omarchy theme bg next`. |

## Palette

Core One Dark values, shared with nvim and tmux:

| Role | Hex | Also used as |
| --- | --- | --- |
| `background` | `#282c34` | tmux `bg` |
| `foreground` | `#abb2bf` | tmux `fg` |
| `accent` / `yellow` | `#e5c07b` | Hyprland active border, bar accent — tmux `yellow` |
| `blue` | `#61afef` | terminal blue, nvim/lualine normal mode |
| `selection` | `#3e4451` | |
| `muted` | `#5c6370` | terminal bright black |

## Install

The live theme is a symlink into this repo, so edits here take effect on the
next `omarchy theme set`:

```bash
ln -s ~/myprojects/dotfiles/.config/omarchy/themes/one-dark \
      ~/.config/omarchy/themes/one-dark
omarchy theme set one-dark
```

After editing `colors.toml`, re-run `omarchy theme set one-dark` to regenerate
every downstream config.
