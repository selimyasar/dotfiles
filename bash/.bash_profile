# ~/.dotfiles/bash/.bash_profile
# Login shell — tema yükleyiciyi içeren .bashrc'yi yükle
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"

# Yerel override (login shell için)
[ -f "$HOME/.bash_profile.local" ] && source "$HOME/.bash_profile.local"
