# .zsh

My Mac terminal environment, in one repo. Clone it on a fresh machine, run one
script, get a working setup: [Ghostty](https://ghostty.org) + Neovim
([LazyVim](https://lazyvim.github.io)) + zsh with a
[starship](https://starship.rs) prompt, all themed Catppuccin.

## Install

```sh
git clone https://github.com/sharpvik/.zsh ~/Desktop/.zsh
cd ~/Desktop/.zsh
./install.sh
```

Then open a new Ghostty window.

The script is **idempotent** — re-run it any time (after a `git pull`, for
instance). A run where nothing has changed makes no changes at all.

## What it does

1. Checks macOS and the Xcode Command Line Tools.
2. Installs Homebrew if missing.
3. `brew bundle` over the [`Brewfile`](./Brewfile) — Ghostty, Neovim, starship,
   the zsh plugins, ripgrep/fd/fzf/node, and a few daily CLI tools.
4. Copies the configs into place, backing up anything it would overwrite to
   `~/.dotfiles-backup/<timestamp>/`.
5. Seeds `~/.zshrc.local` from the template, if you don't already have one.
6. If `github.com:22` is blocked, routes GitHub SSH over port 443.
7. Installs Neovim's plugins headlessly, pinned to the commits in
   `lazy-lock.json`.

### Updating

```sh
./install.sh --update   # upgrade brew packages + plugins to latest
./sync.sh               # capture the new lazy-lock.json
git commit -am "chore: update plugins"
```

Without `--update`, installs are reproducible: you get exactly the versions
recorded in `lazy-lock.json`, not whatever is newest today.

## Layout

```
home/
  .zshrc                  → ~/.zshrc
  .zshrc.local.example    → ~/.zshrc.local  (only if absent)
config/
  starship.toml           → ~/.config/starship.toml
  ghostty/                → ~/.config/ghostty/
  nvim/                   → ~/.config/nvim/
```

## Making changes

Configs are **copied**, not symlinked, so edits to the live files don't show up
in `git diff` by themselves. After tweaking anything:

```sh
./sync.sh        # pulls live configs back into the repo
git diff         # review
git commit -am "tweak: ..."
```

`sync.sh` never commits or pushes — that stays deliberate.

Same workflow for pinning plugin updates: `./install.sh --update` (or
`:Lazy update` in Neovim), then `./sync.sh` and review
`config/nvim/lazy-lock.json`.

## Machine-local settings

Anything personal or machine-specific — private hostnames, account names,
credentials, absolute paths with a username — belongs in `~/.zshrc.local`,
which is sourced by `.zshrc` and is **not** tracked here. Pull secrets from the
macOS Keychain rather than hardcoding them:

```sh
export SOME_TOKEN="$(security find-generic-password -a acct -s service -w 2>/dev/null)"
```

`~/.zshenv` is private and is not touched, read, or referenced by anything in
this repo.

## Notes

- Ghostty embeds JetBrains Mono and Symbols Nerd Font, so no font install is
  needed for the icons in Neovim's statusline and file tree.
- Neovim's LSP servers install lazily via Mason, the first time you open a file
  of each language — so that first open needs network.
- `install.sh` uses `Lazy! restore`, never `Lazy! sync`. `sync` implies *update*:
  it ignores the lockfile, moves every plugin to latest and rewrites the lockfile
  — which is the opposite of a reproducible install. Both run in a convergence
  loop, because lazy resolves the plugin spec from whichever LazyVim happens to
  be checked out at startup, so a single pass can pin the wrong set of plugins.
- `.zshrc` resolves the Homebrew prefix itself and guards every `source`, so it
  degrades gracefully on Intel Macs or a machine missing a plugin.
