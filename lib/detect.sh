#!/usr/bin/env bash
# detect.sh — ortam tespit kütüphanesi
# Kullanım: source ~/.dotfiles/lib/detect.sh
# Sonra: detect_all && echo "$DT_OS / $DT_SHELL / $DT_TERM"

# ─────────────────────────────────────────────
#  Renk çıktısı (tema yokken bile okunabilir)
# ─────────────────────────────────────────────
_dt_ok()   { printf '\033[32m✔\033[0m %s\n' "$*"; }
_dt_info() { printf '\033[34mℹ\033[0m %s\n' "$*"; }
_dt_warn() { printf '\033[33m⚠\033[0m %s\n' "$*"; }
_dt_err()  { printf '\033[31m✖\033[0m %s\n' "$*" >&2; }

# ─────────────────────────────────────────────
#  OS tespiti
#  Çıktı: DT_OS = macos | linux | wsl | unknown
#         DT_DISTRO = ubuntu | debian | fedora | arch | alpine | unknown  (sadece linux)
#         DT_PKG_MGR = brew | apt | dnf | pacman | apk | unknown
# ─────────────────────────────────────────────
detect_os() {
  local uname
  uname="$(uname -s 2>/dev/null)"

  case "$uname" in
    Darwin)
      DT_OS="macos"
      DT_DISTRO="macos"
      DT_PKG_MGR="brew"
      ;;
    Linux)
      # WSL kontrolü
      if grep -qi microsoft /proc/version 2>/dev/null; then
        DT_OS="wsl"
      else
        DT_OS="linux"
      fi

      # Distro tespiti
      if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        DT_DISTRO="$(. /etc/os-release && echo "${ID:-unknown}")"
      else
        DT_DISTRO="unknown"
      fi

      # Paket yöneticisi
      if   command -v apt-get &>/dev/null; then DT_PKG_MGR="apt"
      elif command -v dnf     &>/dev/null; then DT_PKG_MGR="dnf"
      elif command -v yum     &>/dev/null; then DT_PKG_MGR="yum"
      elif command -v pacman  &>/dev/null; then DT_PKG_MGR="pacman"
      elif command -v apk     &>/dev/null; then DT_PKG_MGR="apk"
      elif command -v brew    &>/dev/null; then DT_PKG_MGR="brew"   # linuxbrew
      else                                      DT_PKG_MGR="unknown"
      fi
      ;;
    *)
      DT_OS="unknown"
      DT_DISTRO="unknown"
      DT_PKG_MGR="unknown"
      ;;
  esac

  export DT_OS DT_DISTRO DT_PKG_MGR
}

# ─────────────────────────────────────────────
#  Shell tespiti
#  Çıktı: DT_SHELL = zsh | bash | fish | unknown
#         DT_SHELL_VERSION = "5.9" gibi
# ─────────────────────────────────────────────
detect_shell() {
  # $SHELL login shell'i gösterir, ama biz çalışan shell'i istiyoruz
  local running_shell
  running_shell="$(ps -p $$ -o comm= 2>/dev/null | sed 's/^-//')"

  case "$running_shell" in
    zsh)
      DT_SHELL="zsh"
      DT_SHELL_VERSION="${ZSH_VERSION:-unknown}"
      ;;
    bash)
      DT_SHELL="bash"
      DT_SHELL_VERSION="${BASH_VERSION:-unknown}"
      ;;
    fish)
      DT_SHELL="fish"
      DT_SHELL_VERSION="$(fish --version 2>/dev/null | awk '{print $3}')"
      ;;
    *)
      # Fallback: $SHELL değişkenine bak
      case "${SHELL:-}" in
        */zsh)  DT_SHELL="zsh"  ;;
        */bash) DT_SHELL="bash" ;;
        */fish) DT_SHELL="fish" ;;
        *)      DT_SHELL="unknown" ;;
      esac
      DT_SHELL_VERSION="unknown"
      ;;
  esac

  export DT_SHELL DT_SHELL_VERSION
}

# ─────────────────────────────────────────────
#  Terminal emülatör tespiti
#  Çıktı: DT_TERM = iterm2 | wezterm | kitty | vscode |
#                   apple_terminal | gnome | ssh | unknown
#         DT_IS_SSH = true | false
#         DT_IS_TMUX = true | false
#         DT_COLOR_SUPPORT = truecolor | 256 | basic | none
# ─────────────────────────────────────────────
detect_terminal() {
  # SSH kontrolü
  if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ]; then
    DT_IS_SSH="true"
  else
    DT_IS_SSH="false"
  fi

  # Tmux / screen kontrolü
  if [ -n "${TMUX:-}" ]; then
    DT_IS_TMUX="true"
  else
    DT_IS_TMUX="false"
  fi

  # Terminal emülatör
  # Öncelik sırası önemli: spesifik env değişkenleri önce
  if [ "${DT_IS_SSH}" = "true" ]; then
    DT_TERM="ssh"

  elif [ -n "${ITERM_SESSION_ID:-}" ] || [ "${TERM_PROGRAM:-}" = "iTerm.app" ]; then
    DT_TERM="iterm2"

  elif [ -n "${WEZTERM_EXECUTABLE:-}" ] || [ "${TERM_PROGRAM:-}" = "WezTerm" ]; then
    DT_TERM="wezterm"

  elif [ "${KITTY_WINDOW_ID:-}" ] || [ "${TERM:-}" = "xterm-kitty" ]; then
    DT_TERM="kitty"

  elif [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    DT_TERM="vscode"

  elif [ "${TERM_PROGRAM:-}" = "Apple_Terminal" ]; then
    DT_TERM="apple_terminal"

  elif [ -n "${GNOME_TERMINAL_SCREEN:-}" ] || [ -n "${VTE_VERSION:-}" ]; then
    DT_TERM="gnome"

  else
    DT_TERM="unknown"
  fi

  # Renk desteği
  if [ "${COLORTERM:-}" = "truecolor" ] || [ "${COLORTERM:-}" = "24bit" ]; then
    DT_COLOR_SUPPORT="truecolor"
  elif [ "${TERM:-}" = "xterm-256color" ] || [ "${TERM:-}" = "screen-256color" ]; then
    DT_COLOR_SUPPORT="256"
  elif tput colors &>/dev/null && [ "$(tput colors)" -ge 8 ]; then
    DT_COLOR_SUPPORT="basic"
  else
    DT_COLOR_SUPPORT="none"
  fi

  export DT_TERM DT_IS_SSH DT_IS_TMUX DT_COLOR_SUPPORT
}

# ─────────────────────────────────────────────
#  Mimari tespiti
#  Çıktı: DT_ARCH = arm64 | x86_64 | unknown
# ─────────────────────────────────────────────
detect_arch() {
  local machine
  machine="$(uname -m 2>/dev/null)"
  case "$machine" in
    arm64|aarch64) DT_ARCH="arm64"  ;;
    x86_64|amd64)  DT_ARCH="x86_64" ;;
    *)             DT_ARCH="unknown" ;;
  esac
  export DT_ARCH
}

# ─────────────────────────────────────────────
#  Görünüm (aydınlık/karanlık) tespiti
#  Çıktı: DT_APPEARANCE = light | dark
#  Override: DOTFILES_THEME_MODE=light|dark|auto
# ─────────────────────────────────────────────
detect_appearance() {
  local mode="${DOTFILES_THEME_MODE:-auto}"

  # Elle verilen değer her zaman kazanır (test / SSH / CI)
  if [ "$mode" = "light" ] || [ "$mode" = "dark" ]; then
    DT_APPEARANCE="$mode"
    export DT_APPEARANCE
    return 0
  fi

  DT_APPEARANCE=""

  # macOS: sistem görünümü (yalnızca GUI oturumunda çalışır)
  if [ "$DT_OS" = "macos" ] && command -v defaults &>/dev/null; then
    if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then
      DT_APPEARANCE="dark"
    else
      DT_APPEARANCE="light"
    fi
  fi

  # Diğer terminaller: COLORFGBG="fg;bg" — bg < 7 koyu, bg >= 7 açık
  if [ -z "$DT_APPEARANCE" ] && [ -n "${COLORFGBG:-}" ]; then
    local bg="${COLORFGBG##*;}"
    case "$bg" in
      ''|*[!0-9]*) : ;;  # sayı değilse dokunma
      *) [ "$bg" -ge 7 ] && DT_APPEARANCE="light" || DT_APPEARANCE="dark" ;;
    esac
  fi

  # Bilinemiyorsa mevcut davranışı koru (koyu)
  DT_APPEARANCE="${DT_APPEARANCE:-dark}"
  export DT_APPEARANCE
}

# ─────────────────────────────────────────────
#  Toplu tespit — hepsini çalıştır
# ─────────────────────────────────────────────
detect_all() {
  detect_os
  detect_shell
  detect_terminal
  detect_arch
  detect_appearance
}

# ─────────────────────────────────────────────
#  Debug çıktısı — tüm değişkenleri yazdır
# ─────────────────────────────────────────────
detect_dump() {
  detect_all
  echo ""
  echo "  ┌─ Ortam Raporu ───────────────────────────┐"
  printf  "  │  %-18s %s\n" "OS:"            "${DT_OS} (${DT_DISTRO})"
  printf  "  │  %-18s %s\n" "Paket yöneticisi:" "${DT_PKG_MGR}"
  printf  "  │  %-18s %s\n" "Shell:"         "${DT_SHELL} ${DT_SHELL_VERSION}"
  printf  "  │  %-18s %s\n" "Terminal:"      "${DT_TERM}"
  printf  "  │  %-18s %s\n" "SSH:"           "${DT_IS_SSH}"
  printf  "  │  %-18s %s\n" "Tmux:"          "${DT_IS_TMUX}"
  printf  "  │  %-18s %s\n" "Renk desteği:"  "${DT_COLOR_SUPPORT}"
  printf  "  │  %-18s %s\n" "Görünüm:"       "${DT_APPEARANCE}"
  printf  "  │  %-18s %s\n" "Mimari:"        "${DT_ARCH}"
  echo  "  └──────────────────────────────────────────┘"
  echo ""
}

# ─────────────────────────────────────────────
#  Script doğrudan çalıştırılırsa dump yap
#  source edilirse sessiz kal (bash + zsh uyumlu)
# ─────────────────────────────────────────────
if [ -n "${BASH_VERSION:-}" ]; then
  [ "${BASH_SOURCE[0]}" = "$0" ] && detect_dump
elif [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file*) : ;;          # source edildi → sessiz
    *)       detect_dump ;;  # doğrudan çalıştırıldı → rapor
  esac
fi
