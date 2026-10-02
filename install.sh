#!/usr/bin/env bash
#
# install.sh — set up this Mac's terminal environment from this repo.
#
# Installs Ghostty, Neovim and the CLI tools in ./Brewfile, then copies the
# ghostty / nvim / starship / zsh configs into place and installs Neovim's
# plugins. Safe to re-run: every step is idempotent, and an unchanged run
# makes no changes at all.
#
# Never reads, writes or references ~/.zshenv. That file is private.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
BACKED_UP=0
UPDATE=0

usage() {
  cat <<'USAGE'
usage: ./install.sh [--update]

  (no flags)  Install everything and pin Neovim plugins to the commits in
              lazy-lock.json. Reproducible: you get the versions this repo
              was last known to work with.

  --update    Also upgrade Homebrew packages and Neovim plugins to the
              latest versions, then rewrite lazy-lock.json to match. Run
              ./sync.sh afterwards and commit to make the new pins stick.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --update) UPDATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; echo >&2; echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
warn() { printf '    WARNING: %s\n' "$1" >&2; }
die()  { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

# ── 1. preflight ───────────────────────────────────────────────────
step "Preflight"

[ "$(uname -s)" = "Darwin" ] || die "This installer is macOS-only (found $(uname -s))."
info "macOS $(sw_vers -productVersion) on $(uname -m)"

if ! xcode-select -p >/dev/null 2>&1; then
  info "Xcode Command Line Tools are missing. Launching the installer..."
  xcode-select --install || true
  die "Finish the Command Line Tools install in the GUI, then re-run this script.
       (They provide git and the C compiler that telescope-fzf-native needs.)"
fi
info "Xcode Command Line Tools present"

# ── 2. homebrew ────────────────────────────────────────────────────
step "Homebrew"

if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# A freshly installed brew is not on PATH in this process. Fix that here
# rather than relying on a future login shell.
for prefix in /opt/homebrew /usr/local; do
  if [ -x "$prefix/bin/brew" ]; then
    eval "$("$prefix/bin/brew" shellenv)"
    break
  fi
done
command -v brew >/dev/null 2>&1 || die "Homebrew install succeeded but brew is not on PATH."
info "brew $(brew --version | head -1 | awk '{print $2}') at $(brew --prefix)"

# ── 3. packages ────────────────────────────────────────────────────
step "Packages"

# Ghostty may already be in /Applications from a manual .dmg install, in which
# case `brew bundle` would fail on every run. --adopt hands the existing bundle
# to Homebrew instead of reinstalling it.
if [ -d /Applications/Ghostty.app ] && ! brew list --cask ghostty >/dev/null 2>&1; then
  info "Adopting the existing /Applications/Ghostty.app into Homebrew..."
  brew install --cask ghostty --adopt
fi

brew bundle --file="$REPO_DIR/Brewfile"

if [ "$UPDATE" -eq 1 ]; then
  info "Upgrading Homebrew packages (--update)..."
  brew update
  brew upgrade
fi

# ── 4. configs ─────────────────────────────────────────────────────
step "Configs"

# Copy src -> dest, preserving anything already there that differs.
# Identical content is left alone entirely, so a repeat run is a true no-op.
copy_config() {
  local src="$1" dest="$2" rel="${2#"$HOME"/}"

  [ -e "$src" ] || die "missing from repo: $src"

  if [ -e "$dest" ]; then
    if diff -rq "$src" "$dest" >/dev/null 2>&1; then
      info "unchanged: ~/$rel"
      return
    fi
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -R "$dest" "$BACKUP_DIR/$rel"
    rm -rf "$dest"
    BACKED_UP=1
    info "backed up: ~/$rel"
  fi

  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
  info "installed: ~/$rel"
}

copy_config "$REPO_DIR/home/.zshrc"          "$HOME/.zshrc"
copy_config "$REPO_DIR/config/starship.toml" "$HOME/.config/starship.toml"
copy_config "$REPO_DIR/config/ghostty"       "$HOME/.config/ghostty"
copy_config "$REPO_DIR/config/nvim"          "$HOME/.config/nvim"

# ── 5. machine-local overrides ─────────────────────────────────────
step "Machine-local overrides"

if [ -f "$HOME/.zshrc.local" ]; then
  info "~/.zshrc.local exists, leaving it untouched"
else
  cp "$REPO_DIR/home/.zshrc.local.example" "$HOME/.zshrc.local"
  chmod 600 "$HOME/.zshrc.local"
  info "created ~/.zshrc.local from the template"
fi

# ── 6. github ssh fallback ─────────────────────────────────────────
step "GitHub SSH connectivity"

SSH_MARK="# >>> sharpvik/.zsh github-443-fallback >>>"

# macOS ships no `timeout`, and a blocked port black-holes rather than
# refusing, so bound the probe with nc's own -G connect timeout.
if nc -z -G 5 github.com 22 >/dev/null 2>&1; then
  info "github.com:22 is reachable, no SSH config changes needed"
elif grep -qF "$SSH_MARK" "$HOME/.ssh/config" 2>/dev/null; then
  info "443 fallback already configured"
else
  info "github.com:22 looks blocked, routing GitHub SSH over port 443"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/config"
  mkdir -p "$BACKUP_DIR"
  cp "$HOME/.ssh/config" "$BACKUP_DIR/ssh_config"
  BACKED_UP=1
  cat >> "$HOME/.ssh/config" <<EOF

$SSH_MARK
Host github.com
  HostName ssh.github.com
  Port 443
  User git
# <<< sharpvik/.zsh github-443-fallback <<<
EOF
  chmod 600 "$HOME/.ssh/config"
  info "appended the fallback stanza to ~/.ssh/config"
fi

# ── 7. neovim plugins ──────────────────────────────────────────────
step "Neovim plugins"

# `Lazy! restore` installs any missing plugins AND pins every plugin to the
# commit recorded in lazy-lock.json. Do NOT use `Lazy! sync` here: sync implies
# update, which ignores the lockfile, moves everything to latest and rewrites
# lazy-lock.json -- the opposite of a reproducible install.
#
# One pass is not always enough. lazy resolves the plugin spec at startup from
# whatever LazyVim code is checked out at that moment, so if LazyVim itself is
# at the wrong version, restore pins the WRONG SET of plugins and rewrites the
# lockfile accordingly. Repeat until the lockfile stops moving: by then LazyVim
# is pinned too, so the resolved spec is the right one.
REPO_LOCK="$REPO_DIR/config/nvim/lazy-lock.json"
LIVE_LOCK="$HOME/.config/nvim/lazy-lock.json"

if [ "$UPDATE" -eq 1 ]; then
  info "Updating plugins to the latest versions (--update)..."
  prev=""
  for pass in 1 2 3; do
    nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || \
      warn "Lazy sync reported a problem on pass $pass."
    cur="$(shasum "$LIVE_LOCK" | awk '{print $1}')"
    [ "$cur" = "$prev" ] && break
    prev="$cur"
  done
  info "plugins updated (converged after pass $pass)"
  info "run ./sync.sh and commit to pin these versions in the repo"
  exit_after_update=1
fi

if [ "${exit_after_update:-0}" -eq 0 ]; then
info "Restoring plugins to the commits pinned in lazy-lock.json (may take a minute)..."
converged=0
for pass in 1 2 3; do
  cp "$REPO_LOCK" "$LIVE_LOCK"
  if ! nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1; then
    warn "Lazy restore reported a problem on pass $pass."
  fi
  if diff -q "$REPO_LOCK" "$LIVE_LOCK" >/dev/null 2>&1; then
    info "plugins pinned to lazy-lock.json (converged after pass $pass)"
    converged=1
    break
  fi
done
if [ "$converged" -eq 0 ]; then
  cp "$REPO_LOCK" "$LIVE_LOCK"
  warn "plugin versions did not converge to the lockfile after 3 passes."
  warn "Open nvim and run :Lazy restore manually to inspect."
fi
fi

# ── 8. summary ─────────────────────────────────────────────────────
step "Done"

cat <<EOF

    Installed:  Ghostty, Neovim + plugins, starship, zsh plugins, CLI tools
    Configs:    ~/.zshrc, ~/.config/{starship.toml,ghostty,nvim}

EOF

if [ "$BACKED_UP" -eq 1 ]; then
  echo "    Replaced files were backed up to:"
  echo "      $BACKUP_DIR"
  echo
fi

echo "    Next:"
echo "      1. Open a NEW Ghostty window (or run 'exec zsh') to pick up the shell config."
if [ "${SHELL:-}" != "/bin/zsh" ] && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  echo "      2. Your login shell is ${SHELL:-unknown}; run 'chsh -s /bin/zsh' to switch to zsh."
fi
echo
echo "    Note: Neovim's LSP servers (via Mason) install lazily the first time you"
echo "    open a file of each language, so you'll want network access then."
echo
