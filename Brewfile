# Brewfile — everything this setup needs on a fresh Mac.
# Applied by install.sh via `brew bundle`. Idempotent: already-installed
# packages are skipped.

# ── terminal ───────────────────────────────────────────────────────
cask "ghostty"          # embeds JetBrains Mono + Symbols Nerd Font

# ── editor ─────────────────────────────────────────────────────────
brew "neovim"

# ── shell ──────────────────────────────────────────────────────────
brew "starship"                  # prompt
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

# ── neovim runtime deps ────────────────────────────────────────────
brew "ripgrep"          # telescope live_grep
brew "fd"               # telescope file finding
brew "fzf"
brew "node"             # mason-installed LSP servers (jsonls, yamlls, ...)
brew "git"

# ── daily drivers ──────────────────────────────────────────────────
brew "gh"
brew "tree"
brew "htop"
brew "wget"
brew "pandoc"
brew "ffmpeg"
brew "poppler"
