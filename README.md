# HERDR

> Terminal multiplexer with AI agent tracking. Built for developers who run multiple AI agents concurrently.

![HERDR](Captura%20de%20pantalla%20de%202026-07-17%2014-09-02.png)

## What is HERDR?

HERDR is a terminal multiplexer — like tmux or zellij — with one key difference: it tracks the status of your AI agents in a sidebar. Instead of switching between panes to check if Pi finished a task or OpenCode is waiting for input, you see everything at a glance.

**Key features:**

- Agent status tracking (idle, running, waiting)
- Workspace management with panes
- Theme support (Catppuccin, Gruvbox, Nord, Dracula)
- Shell auto-start (Bash, Zsh, Fish, Nushell)
- Live config reload without restart
- Agent integrations (Pi, OpenCode, Antigravity)

## Installation (Unix)

### 1. Install the binary

```bash
# Detect your architecture
uname -m   # x86_64 or aarch64
uname -s   # Linux

# Install
curl -fsSL https://herdr.dev/install.sh | sh
```

Verify:

```bash
herdr --version
```

If not found, add to PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

### 2. Create the config

HERDR works without a config file. Create one only when you need custom settings.

```bash
mkdir -p ~/.config/herdr
herdr --default-config > ~/.config/herdr/config.toml
```

Edit to your preference:

```bash
vim ~/.config/herdr/config.toml
```

Recommended config:

```toml
# General
onboarding = false
channel = "stable"

# Theme
[ui]
theme = "catppuccin"

# Sidebar
[ui.sidebar]
enabled = true
position = "left"

# Notifications
[notifications]
enabled = true

[notifications.sound]
enabled = true

# Sessions
[session]
resume_agents_on_restore = true

# Terminal
[terminal]
scrollback_lines = 10000

# Mouse
[mouse]
enabled = true
```

Verify:

```bash
herdr server reload-config
```

### 3. Configure shell auto-start

Add the appropriate block to your shell config:

**Zsh** (`~/.zshrc`):

```bash
cat >> ~/.zshrc << 'EOF'

# HERDR auto-start
if [[ -z "$HERDR_ENV" && -z "$TMUX" && -z "$ZELLIJ" ]]; then
  if command -v herdr &>/dev/null; then
    exec herdr
  fi
fi
EOF
source ~/.zshrc
```

**Bash** (`~/.bashrc`):

```bash
cat >> ~/.bashrc << 'EOF'

# HERDR auto-start
if [ -z "$HERDR_ENV" ] && [ -z "$TMUX" ] && [ -z "$ZELLIJ" ]; then
  if command -v herdr &>/dev/null; then
    exec herdr
  fi
fi
EOF
source ~/.bashrc
```

**Fish** (`~/.config/fish/config.fish`):

```bash
cat >> ~/.config/fish/config.fish << 'EOF'

# HERDR auto-start
if not set -q HERDR_ENV; and not set -q TMUX; and not set -q ZELLIJ
    if command -q herdr
        exec herdr
    end
end
EOF
```

**Nushell** (`~/.config/nushell/config.nu`):

```bash
cat >> ~/.config/nushell/config.nu << 'EOF'

# HERDR auto-start
if ($env | get -i HERDR_ENV | is-empty) and ($env | get -i TMUX | is-empty) and ($env | get -i ZELLIJ | is-empty) {
    if (which herdr | is-not-empty) {
        exec herdr
    }
}
EOF
```

### 4. Install agent integrations

```bash
# Install integrations
herdr integration install pi
herdr integration install opencode
herdr integration install antigravity

# Verify
herdr integration status
```

### 5. Verify everything

```bash
herdr --version
cat ~/.config/herdr/config.toml
herdr integration status
herdr
```

## Updating

```bash
herdr update
```

## License

MIT
