# Voxtype (Linux)

Local Whisper voice-to-text, tuned for dictating to coding agents (Claude Code, pi). `make setup` links `config.toml` only where `voxtype` is installed.

What the config does:

- **Vocabulary**: `initial_prompt` biases Whisper toward terms like Omarchy, Neovim, tmux, Claude Code, pi.dev; `[text.replacements]` fixes misspellings seen in the logs (`journalctl --user -u voxtype | grep Transcribed`).
- **Tap to dictate**: recordings started by `voxtype record start` stop after `external_trigger_silence_timeout_secs` of silence.
- **Agent-friendly output**: say "submit" at the end to press Enter (`smart_auto_submit`); line breaks are typed as Shift+Enter so they don't send a prompt early; a space separates consecutive dictations.

Machine-specific values to revisit on a new machine:

- `external_trigger_speech_threshold_dbfs = -40` was set for the 2017 MacBook Pro mic. If recordings stop after a second or so while you're still talking, lower it; if they never stop, raise it toward -20.
- `model = "small.en"` with `context_window_optimization` suits that machine's GPU. Download the model with `voxtype setup --download --model small.en` and the VAD model with `voxtype setup vad`.

Edit `config.toml` directly rather than through `voxtype configure`, which may replace the symlink with a plain file (`make doctor` flags it). Restart after changes: `systemctl --user restart voxtype`.

## Telling the agent about dictation

Some mishearings are real words (pane/pain, commit/comment), so replacements can't safely fix them. Instead, add this to each machine's agent instructions: `~/.claude/CLAUDE.md` for Claude Code, or pi's appended system prompt. It isn't linked from here because those files are per-machine.

```markdown
# Voice input

Many of my prompts are dictated with VoxType (local Whisper), not typed. Expect transcription errors and interpret intent rather than taking wording literally.

Common mishearings:
- pain / paints / Payne → pane (tmux)
- comment(s) → commit(s), when talking about git
- commons → comments
- new one / new win / Neo Win / WIM → Neovim / Vim
- miss / MISC → mise
- Omachi / a Marchy → Omarchy
- cloud / clod → Claude
- Py.dev / pie.dev → pi.dev
- punk / hunger → hunk
- diamond / Dyson → diagram

Dictated prompts may be cut off mid-sentence or arrive as several fragments. If a request is genuinely ambiguous after accounting for this, ask rather than guess.
```

## Hyprland bindings (not linked)

`~/.config/hypr/bindings.lua` is Omarchy-owned and `omarchy refresh hyprland` replaces it, so these lines are added by hand:

```lua
-- Tap to dictate; voxtype stops by itself after a pause (audio.external_trigger_silence_timeout_secs).
o.bind("SUPER + D", "Dictate (auto-stop on silence)", "voxtype record start")
o.bind("SUPER + ALT + D", "Cancel dictation", "voxtype record cancel")
```

Check the keys are free first (`omarchy menu keybindings --print`); Omarchy's own defaults (F9 push-to-talk, Super+Ctrl+X toggle) keep working alongside them.
