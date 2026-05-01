# ~/.dotfiles/bash/.bashrc
# Interaktif shell değilse çık
[[ $- != *i* ]] && return

# ── Temel bash ayarları ───────────────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s cdspell
shopt -s autocd 2>/dev/null || true

# ── Dotfiles tema yükleyici ───────────────────────────────────────────────────
# dotfiles:theme
[ -f "$HOME/.dotfiles/lib/theme.sh" ] && source "$HOME/.dotfiles/lib/theme.sh"

# ── Yerel override ───────────────────────────────────────────────────────────
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
