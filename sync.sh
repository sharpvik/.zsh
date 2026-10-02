#!/usr/bin/env bash
#
# sync.sh — copy live configs on this Mac back into the repo.
#
# install.sh copies files out of the repo, so edits made to the live configs
# don't show up in `git diff` on their own. Run this after tweaking anything,
# then review and commit.
#
# Never reads, writes or references ~/.zshenv or ~/.zshrc.local. Those are
# private / machine-local and deliberately stay out of the repo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '    %s\n' "$1"; }

sync_file() {
  local live="$1" repo="$2"
  if [ ! -e "$live" ]; then
    info "skipped (not present): $live"
    return
  fi
  mkdir -p "$(dirname "$repo")"
  cp "$live" "$repo"
  info "synced: $live"
}

printf '\n==> Syncing live configs into %s\n' "$REPO_DIR"

sync_file "$HOME/.zshrc"                 "$REPO_DIR/home/.zshrc"
sync_file "$HOME/.config/starship.toml"  "$REPO_DIR/config/starship.toml"
sync_file "$HOME/.config/ghostty/config" "$REPO_DIR/config/ghostty/config"

# rsync rather than cp for nvim: --delete mirrors removals too, so a spec file
# deleted from ~/.config/nvim also disappears from the repo. .git is excluded
# because ~/.config/nvim may still be a repo of its own.
if [ -d "$HOME/.config/nvim" ]; then
  rsync -a --delete --exclude='.git' "$HOME/.config/nvim/" "$REPO_DIR/config/nvim/"
  info "synced: ~/.config/nvim/"
else
  info "skipped (not present): ~/.config/nvim"
fi

printf '\n==> Repo status\n\n'
if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$REPO_DIR" status --short
  printf '\n    Review with:  git -C %s diff\n\n' "$REPO_DIR"
else
  info "not a git repo yet — run 'git init' here first"
fi
