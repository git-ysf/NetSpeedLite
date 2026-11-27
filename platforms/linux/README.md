# NetSpeedLite for Linux

Ultra-featherlight, zero-dependency native C99 network speed monitor reading `/proc/net/dev` with microsecond monotonic deltas.

## Features

- **Zero dependencies**: Pure C99 + POSIX/Linux standard headers (`~20 KB` stripped binary, `< 2 MB` RSS).
- **Waybar mode (`--waybar`)**: Streaming JSON with UTF-8 sparkline, per-interface tooltip, and CSS state classes (`idle`, `active`, `high`).
- **Polybar mode (`--polybar`)**: Streaming `%{F#...}` color-tagged output for `tail = true`.
- **Live Terminal TUI (`--tui`)**: Alternate-screen ANSI UI with dual upload/download sparklines, 6 color themes (`dark`, `light`, `nord`, `dracula`, `catppuccin`, `mono`), peak tracking, and per-interface table.
- **Scripting (`--once` / `--json`)**: Single-shot human-readable or JSON output.

## Build & Install

```sh
cd platforms/linux
make
sudo make install
```

Or install to `~/.local/bin` without root:

```sh
./install.sh --user
```

## Usage

```sh
netspeedlite --tui                  # Live terminal UI
netspeedlite --waybar               # Waybar JSON stream
netspeedlite --polybar --theme nord # Polybar stream
netspeedlite --once                 # Single snapshot
netspeedlite --json -i eth0         # Single JSON snapshot for eth0
```

## Bar Integration

- **Waybar**: Copy [waybar/config.jsonc](waybar/config.jsonc) and [waybar/style.css](waybar/style.css) into `~/.config/waybar/`.
- **Polybar**: Copy [polybar/config.ini](polybar/config.ini) into `~/.config/polybar/config.ini`.
- **Desktop Entry**: `make install` installs `netspeedlite.desktop` for application launchers.
