#!/usr/bin/env bash
# theme.sh — terminal açıldığında ortama göre tema yükler
# Kullanım: ~/.zshrc veya ~/.bashrc içine şunu ekle:
#   [ -f "$HOME/.dotfiles/lib/theme.sh" ] && source "$HOME/.dotfiles/lib/theme.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
THEME_CONFIG_DIR="$DOTFILES_DIR/themes"

# ─────────────────────────────────────────────
#  detect.sh yüklü değilse yükle
# ─────────────────────────────────────────────
if [ -z "${DT_OS:-}" ]; then
  if [ -f "$DOTFILES_DIR/lib/detect.sh" ]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_DIR/lib/detect.sh"
    detect_all
  else
    # detect.sh yoksa minimal tespit yap
    DT_OS="unknown"
    DT_SHELL="${SHELL##*/}"
    DT_TERM="${TERM_PROGRAM:-unknown}"
    DT_IS_SSH="${SSH_CONNECTION:+true}"
    DT_IS_SSH="${DT_IS_SSH:-false}"
    DT_COLOR_SUPPORT="256"
  fi
fi

# ─────────────────────────────────────────────
#  Starship config seçimi
#  Ortama göre farklı profil → farklı starship.toml
# ─────────────────────────────────────────────
_load_starship() {
  command -v starship &>/dev/null || return 0

  local config_file

  # Öncelik: SSH > tmux > terminal emülatör
  if [ "$DT_IS_SSH" = "true" ]; then
    config_file="$THEME_CONFIG_DIR/starship-ssh.toml"
  elif [ "$DT_IS_TMUX" = "true" ]; then
    config_file="$THEME_CONFIG_DIR/starship-tmux.toml"
  elif [ "$DT_COLOR_SUPPORT" = "truecolor" ]; then
    config_file="$THEME_CONFIG_DIR/starship-full.toml"
  else
    config_file="$THEME_CONFIG_DIR/starship-minimal.toml"
  fi

  # Config yoksa varsayılanı kullan
  if [ ! -f "$config_file" ]; then
    config_file="$DOTFILES_DIR/starship.toml"
  fi

  export STARSHIP_CONFIG="$config_file"

  # Shell'e göre starship init
  case "$DT_SHELL" in
    zsh)  eval "$(starship init zsh)"  ;;
    bash) eval "$(starship init bash)" ;;
    fish) starship init fish | source  ;;  # fish içinden çağrılırsa
  esac
}

# ─────────────────────────────────────────────
#  Renk şeması (terminal emülatöre özel)
#  OSC escape dizileriyle terminale renk yükler
# ─────────────────────────────────────────────
_apply_color_scheme() {
  # SSH veya renk desteği yoksa uygulama
  [ "$DT_IS_SSH" = "true" ]          && return 0
  [ "$DT_COLOR_SUPPORT" = "none" ]   && return 0
  [ "$DT_COLOR_SUPPORT" = "basic" ]  && return 0

  case "$DT_TERM" in
    iterm2)
      _apply_iterm2_colors
      ;;
    wezterm)
      _apply_wezterm_colors
      ;;
    apple_terminal)
      # Apple Terminal OSC desteği sınırlı, sadece başlık ayarla
      _set_terminal_title
      ;;
    kitty)
      # Kitty kendi config'ini kullanır, burada karıştırma
      ;;
    *)
      # Bilinmeyen terminal — sadece 256 renk palette ayarla
      _apply_ansi_colors
      ;;
  esac
}

# OSC 4 ile ANSI renk paletini yeniden tanımla (her terminalde çalışır)
_apply_ansi_colors() {
  [ "$DT_COLOR_SUPPORT" = "none" ] && return 0
  # Tokyonight color palette — terminal'in 16 ANSI rengini override eder
  printf '\033]4;0;#1a1b26\007'   # black
  printf '\033]4;1;#f7768e\007'   # red
  printf '\033]4;2;#9ece6a\007'   # green
  printf '\033]4;3;#e0af68\007'   # yellow
  printf '\033]4;4;#7aa2f7\007'   # blue
  printf '\033]4;5;#bb9af7\007'   # magenta
  printf '\033]4;6;#7dcfff\007'   # cyan
  printf '\033]4;7;#a9b1d6\007'   # white
  printf '\033]4;8;#414868\007'   # bright black
  printf '\033]4;9;#f7768e\007'   # bright red
  printf '\033]4;10;#9ece6a\007'  # bright green
  printf '\033]4;11;#e0af68\007'  # bright yellow
  printf '\033]4;12;#7aa2f7\007'  # bright blue
  printf '\033]4;13;#bb9af7\007'  # bright magenta
  printf '\033]4;14;#7dcfff\007'  # bright cyan
  printf '\033]4;15;#c0caf5\007'  # bright white
  # Arka plan ve ön plan rengi
  printf '\033]10;#c0caf5\007'    # foreground
  printf '\033]11;#1a1b26\007'    # background
  printf '\033]12;#c0caf5\007'    # cursor
}

# iTerm2: proprietary escape ile profil veya renk şeması değiştir
_apply_iterm2_colors() {
  _apply_ansi_colors   # OSC 4 iTerm2'de de çalışır

  # iTerm2'ye özel: sekme rengini git branch'ine göre ayarla (isteğe bağlı)
  # printf '\033]6;1;bg;red;brightness;26\007'
  # printf '\033]6;1;bg;green;brightness;27\007'
  # printf '\033]6;1;bg;blue;brightness;38\007'
  :
}

# WezTerm: config.lua zaten temayı yönetir, burada sadece env var set et
_apply_wezterm_colors() {
  export WEZTERM_THEME="tokyonight"
  _apply_ansi_colors
}

# ─────────────────────────────────────────────
#  Terminal başlığı
# ─────────────────────────────────────────────
_set_terminal_title() {
  [ "$DT_COLOR_SUPPORT" = "none" ] && return 0

  # Her komut çalıştığında başlığı güncelle
  case "$DT_SHELL" in
    zsh)
      # precmd hook ile — her prompt'tan önce çalışır
      autoload -Uz add-zsh-hook 2>/dev/null
      _theme_set_title() {
        local title
        if [ "$DT_IS_SSH" = "true" ]; then
          title="${USER}@${HOST##*.}: ${PWD/#$HOME/~}"
        else
          title="${PWD/#$HOME/~}"
        fi
        printf '\033]0;%s\007' "$title"
      }
      add-zsh-hook precmd _theme_set_title 2>/dev/null
      ;;
    bash)
      PS1='\[\033]0;${DT_IS_SSH:+${USER}@${HOSTNAME}: }${PWD/#$HOME/~}\007\]'"$PS1"
      ;;
  esac
}

# ─────────────────────────────────────────────
#  fzf entegrasyonu — tema ile uyumlu renkler
# ─────────────────────────────────────────────
_load_fzf() {
  command -v fzf &>/dev/null || return 0

  # Tokyonight temasıyla uyumlu fzf renkleri
  export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border=rounded
    --prompt='❯ '
    --pointer='▶'
    --marker='✓'
    --color=bg+:#1e2030,bg:#1a1b26,spinner:#bb9af7,hl:#7aa2f7
    --color=fg:#a9b1d6,header:#7aa2f7,info:#7dcfff,pointer:#bb9af7
    --color=marker:#9ece6a,fg+:#c0caf5,prompt:#7aa2f7,hl+:#7aa2f7
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-u:preview-half-page-up'
    --bind='ctrl-d:preview-half-page-down'
  "

  # SSH'ta preview'ı kapat (performans)
  if [ "$DT_IS_SSH" = "true" ]; then
    export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --no-preview"
  fi

  # fd varsa fzf'in dosya arama backend'ini değiştir
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi

  # Key bindings ve completion yükle
  case "$DT_SHELL" in
    zsh)
      local fzf_zsh
      for p in \
        "$HOME/.fzf.zsh" \
        "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.zsh" \
        "/usr/share/doc/fzf/examples/key-bindings.zsh" \
        "/usr/share/fzf/key-bindings.zsh"
      do
        if [ -f "$p" ]; then fzf_zsh="$p"; break; fi
      done
      [ -n "$fzf_zsh" ] && source "$fzf_zsh"
      ;;
    bash)
      local fzf_bash
      for p in \
        "$HOME/.fzf.bash" \
        "$(brew --prefix 2>/dev/null)/opt/fzf/shell/key-bindings.bash" \
        "/usr/share/doc/fzf/examples/key-bindings.bash" \
        "/usr/share/fzf/key-bindings.bash"
      do
        if [ -f "$p" ]; then fzf_bash="$p"; break; fi
      done
      [ -n "$fzf_bash" ] && source "$fzf_bash"
      ;;
  esac
}

# ─────────────────────────────────────────────
#  zoxide entegrasyonu
# ─────────────────────────────────────────────
_load_zoxide() {
  command -v zoxide &>/dev/null || return 0

  case "$DT_SHELL" in
    zsh)  eval "$(zoxide init zsh)"  ;;
    bash) eval "$(zoxide init bash)" ;;
    fish) zoxide init fish | source  ;;
  esac
}

# ─────────────────────────────────────────────
#  eza alias'ları — ls'in yerini al
# ─────────────────────────────────────────────
_load_eza_aliases() {
  if ! command -v eza &>/dev/null; then
    # eza yoksa renkli ls
    alias ls='ls --color=auto' 2>/dev/null \
      || alias ls='ls -G'      2>/dev/null \
      || true
    return 0
  fi

  local icon_flag=""
  # SSH veya Nerd Font yoksa ikonları kapat
  if [ "$DT_IS_SSH" = "false" ] && [ "$DT_COLOR_SUPPORT" = "truecolor" ]; then
    icon_flag="--icons"
  fi

  # shellcheck disable=SC2139
  alias ls="eza $icon_flag --group-directories-first"
  alias ll="eza $icon_flag --group-directories-first -l --git --time-style=relative"
  alias la="eza $icon_flag --group-directories-first -la --git --time-style=relative"
  alias lt="eza $icon_flag --tree --level=2"
  alias lta="eza $icon_flag --tree --level=3 -a --ignore-glob='.git|node_modules|__pycache__'"
}

# ─────────────────────────────────────────────
#  Genel alias'lar & env
# ─────────────────────────────────────────────
_load_common() {
  # PATH: local bin
  export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

  # Editör
  if command -v nvim &>/dev/null; then
    export EDITOR="nvim"
    export VISUAL="nvim"
  elif command -v vim &>/dev/null; then
    export EDITOR="vim"
    export VISUAL="vim"
  fi

  # Genel alias'lar
  alias ..='cd ..'
  alias ...='cd ../..'
  alias mkdir='mkdir -p'
  alias cp='cp -iv'
  alias mv='mv -iv'
  alias df='df -h'
  alias du='du -sh'
  alias grep='grep --color=auto'

  # Git kısayolları
  alias g='git'
  alias gs='git status'
  alias ga='git add'
  alias gc='git commit'
  alias gp='git push'
  alias gl='git log --oneline --graph --decorate -15'
  alias gd='git diff'

  # Platform'a özgü clipboard
  if [ "$DT_OS" = "macos" ]; then
    alias pbcopy='pbcopy'
    alias pbpaste='pbpaste'
  elif command -v xclip &>/dev/null; then
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
  elif command -v xsel &>/dev/null; then
    alias pbcopy='xsel --clipboard --input'
    alias pbpaste='xsel --clipboard --output'
  fi
}

# ─────────────────────────────────────────────
#  SSH oturumunu bildir
# ─────────────────────────────────────────────
_ssh_banner() {
  [ "$DT_IS_SSH" != "true" ] && return 0
  printf '\033[34m[ssh]\033[0m %s → \033[32m%s\033[0m\n' \
    "${USER}@${HOSTNAME:-$(hostname)}" "${PWD/#$HOME/~}"
}

# ─────────────────────────────────────────────
#  Ana yükleyici — sıra önemli
# ─────────────────────────────────────────────
theme_load() {
  _load_common          # PATH, env, alias — her şeyden önce
  _apply_color_scheme   # terminal renklerini yükle
  _set_terminal_title   # başlık hook'unu kur
  _load_fzf             # fzf renk + key binding
  _load_zoxide          # zoxide init (z komutu)
  _load_eza_aliases     # ls → eza
  _load_starship        # prompt — en son (PS1'i override eder)
  _ssh_banner           # SSH'taysa bilgi satırı bas
}

theme_load
