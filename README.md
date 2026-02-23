# clu - Claude Usage Monitor

A tiny terminal widget that shows your Claude Code usage in real time, with a cute animated companion.

![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue)

## What it does

`clu` reads your Claude Code OAuth token (no extra setup needed) and displays:

- **5-hour** sliding window usage with progress bar
- **7-day** sliding window usage with progress bar
- Reset countdowns for each window
- Token counts for the current period
- A little animated creature to keep you company

## Installation

```bash
# Clone the repo
git clone https://github.com/hsantanna/clu.git
cd clu

# Install dependencies
pip install rich requests

# Make it executable and add to your PATH
chmod +x clu.py
cp clu.py ~/.local/bin/clu
```

## Usage

```bash
# Basic usage (refreshes every 30 seconds)
clu

# Custom refresh interval
clu --refresh 60

# Don't resize the terminal window
clu --no-resize

# Pass a token directly
clu --token sk-ant-...
```

### Options

| Flag | Description |
|------|-------------|
| `--refresh N` | Refresh interval in seconds (default: 30) |
| `--no-resize` | Don't resize the terminal window |
| `--token TOKEN` | Override OAuth token |

## Token Resolution

`clu` automatically finds your Claude Code OAuth token by checking (in order):

1. `CLAUDE_TOKEN` environment variable
2. macOS Keychain (multiple known service names)
3. Credential JSON files (`~/.claude/.credentials.json`, etc.)

If you've used Claude Code at least once, it should just work.

## Requirements

- Python 3.9+
- `rich` - terminal formatting
- `requests` - HTTP client

## License

MIT
