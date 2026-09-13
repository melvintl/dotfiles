# Kanata (macOS)

Two configs live here:

- `kanata.kbd` — generic home-row mods, portable across machines. Linux picks
  it up by default from `~/.config/kanata/kanata.kbd`.
- `kanata_macos.kbd` — MacBook Pro-specific: drops the misfire-prone pinky
  mods (A / ;) and adds the F-row media/brightness layer. Must be passed
  explicitly via `--cfg`.

Kanata needs the Karabiner virtual HID driver to grab keyboard input on macOS.

## Install (once)

```bash
brew install kanata
brew install --cask karabiner-elements
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
```

Then approve the driver: **System Settings → General → Login Items & Extensions → Driver Extensions** → enable `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` (reboot if prompted).

Verify:

```bash
systemextensionsctl list | grep -i karabiner   # expect [activated enabled]
```

Grant **Input Monitoring** to both the `kanata` binary and your terminal: **System Settings → Privacy & Security → Input Monitoring**.

## Run

1. Start the virtual HID daemon:

   ```bash
   sudo "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
   ```

2. Start kanata:

   ```bash
   sudo kanata --cfg ~/.config/kanata/kanata_macos.kbd
   ```

## Gotchas

- After macOS updates, re-activate the driver (`...Manager activate`).
- Keys feel stuck? `sudo pkill kanata`.
- "Allow" button only appears for ~30 min after activate — re-run if needed.
