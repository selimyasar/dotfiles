# AGENTS.md

Portable dotfiles system: one `setup.sh` clones/updates the repo, installs CLI tools, symlinks configs, and injects a theme loader. UI text and code comments are **Turkish** — keep them Turkish. All code is Bash; there is no build step, test suite, CI, or linter config.

## Verify changes

No automated tests. Verify with:

- `bash -n setup.sh lib/*.sh` — syntax check (run this for every edit)
- `shellcheck setup.sh lib/*.sh` — code already uses `# shellcheck disable=...` directives; shellcheck is not installed in this environment
- `bash setup.sh --dry-run` — exercises the full install/symlink flow without changing anything
- `bash lib/detect.sh` — prints the detected-environment report
- `source lib/detect.sh && detect_all` — populates the `DT_*` vars for interactive testing
- `source lib/install.sh && install_status` — list installed tools (safe; do **not** run `bash lib/install.sh` directly, it performs a real install)

## Architecture

- `setup.sh` — orchestrator. Order matters: `_check_prerequisites → _clone_or_update_repo → _install_tools → _link_configs → _inject_theme_loader → _configure_git`. Wrapped in `set -euo pipefail` with an `ERR` trap that logs to `$TMPDIR/dotfiles-setup-*.log`. All mutating commands go through `_run`, which is a no-op that prints instead under `--dry-run`.
- `lib/detect.sh` — sets and **exports** `DT_OS`, `DT_DISTRO`, `DT_PKG_MGR`, `DT_SHELL`, `DT_TERM`, `DT_IS_SSH`, `DT_IS_TMUX`, `DT_COLOR_SUPPORT`, `DT_ARCH`, `DT_APPEARANCE` (light/dark, via `defaults read -g AppleInterfaceStyle` on macOS or `COLORFGBG`). Running it directly prints a report; when sourced it stays silent.
- `lib/install.sh` — package installers. Requires `DT_*` vars; if `DT_OS` is unset it auto-sources `detect.sh` from its own dir (guard at top). Every `install_*` first checks `_has <cmd>` (idempotent). `sudo` falls back to `~/.local/bin` installs when unavailable.
- `lib/theme.sh` — sourced from `.zshrc`/`.bashrc` on **every shell startup**; it calls `theme_load` at the bottom (not guarded by `BASH_SOURCE`, so sourcing it always runs). `theme_load` order matters: common env/aliases → colors → title → fzf → zoxide → eza → starship (starship last, it overrides `PS1`), then `_register_hooks`. The hooks add a 5s-cached appearance re-check on each prompt (macOS + `auto` only) and reset the palette (`OSC 104/110/111/112`) on shell exit.
- `themes/starship-*.toml` symlinked to `~/.config/dotfiles-themes/`; `lib/theme.sh` picks a profile by priority SSH > tmux > truecolor, then swaps to the `-light` variant when `DT_APPEARANCE=light`. `starship-minimal.toml` is mode-agnostic (ANSI color names, no Nerd Font icons).

## Conventions

- Internal helpers are `_`-prefixed; detect vars are `DT_*`; installers are `install_*`.
- Keep everything idempotent: installers check `_has`, `setup.sh`'s `_symlink` skips already-correct links and only overwrites with `--force` (backing up to `*.bak.<timestamp>`).
- User-specific overrides go in `~/.zshrc.local` / `~/.bashrc.local`, sourced at the end of the rc files.
- Theme overrides: `DOTFILES_THEME_MODE=light|dark|auto` forces appearance (`detect.sh`); `DOTFILES_FORCE_BG=1` lets the palette rewrite the terminal's OSC 10/11/12 fg/bg/cursor — off by default so it doesn't clash with the terminal's own light/dark profiles; `DOTFILES_RESET_COLORS=0` disables the palette reset on shell exit.

## Gotchas

- Default repo is hardcoded to `https://github.com/selimyasar/dotfiles.git` (override via `DOTFILES_REPO`/`--repo=`).
- `bash/.bashrc` has an interactive-only guard (`[[ $- != *i* ]] && return`); `.bash_profile` just sources `.bashrc`, so the theme only loads in interactive shells.
- The theme rewrites the terminal's ANSI palette (OSC 4) at startup and resets it on exit; it never touches fg/bg/cursor unless `DOTFILES_FORCE_BG=1`. `kitty` is intentionally skipped (manages its own colors); SSH/none/basic skip color application entirely.
- Never run `bash lib/install.sh` or `bash setup.sh` (without `--dry-run`) to test — they install packages and rewrite `$HOME` symlinks/rc files.
