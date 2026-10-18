#!/usr/bin/env bash
# install.sh — bağımlılık kontrolü & paket kurulum kütüphanesi
# Kullanım: source ~/.dotfiles/lib/install.sh
# Gereksinim: detect.sh önceden source edilmiş olmalı

# ─────────────────────────────────────────────
#  Guard — detect.sh yüklü mü?
# ─────────────────────────────────────────────
if [ -z "${DT_OS:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  if [ -f "$SCRIPT_DIR/detect.sh" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/detect.sh"
    detect_all
  else
    echo "✖ detect.sh bulunamadı. Önce detect.sh source edilmeli." >&2
    return 1 2>/dev/null || exit 1
  fi
fi

# ─────────────────────────────────────────────
#  Yardımcılar
# ─────────────────────────────────────────────
_ok()    { printf '\033[32m✔\033[0m %s\n' "$*"; }
_info()  { printf '\033[34mℹ\033[0m %s\n' "$*"; }
_warn()  { printf '\033[33m⚠\033[0m %s\n' "$*"; }
_err()   { printf '\033[31m✖\033[0m %s\n' "$*" >&2; }
_step()  { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }

# Komut var mı?
_has() { command -v "$1" &>/dev/null; }

# sudo gerekli mi?
_sudo() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  elif _has sudo; then
    sudo "$@"
  else
    _err "sudo bulunamadı ve root değilsiniz: $*"
    return 1
  fi
}

# ─────────────────────────────────────────────
#  Paket yöneticisi wrapper'ları
#  pkg_install <paket_adı> [paket_adı...]
# ─────────────────────────────────────────────
pkg_install() {
  [ $# -eq 0 ] && return 0

  case "$DT_PKG_MGR" in
    brew)
      brew install "$@"
      ;;
    apt)
      _sudo apt-get update -qq
      _sudo apt-get install -y "$@"
      ;;
    dnf)
      _sudo dnf install -y "$@"
      ;;
    yum)
      _sudo yum install -y "$@"
      ;;
    pacman)
      _sudo pacman -Sy --noconfirm "$@"
      ;;
    apk)
      _sudo apk add --no-cache "$@"
      ;;
    *)
      _err "Bilinmeyen paket yöneticisi: $DT_PKG_MGR"
      return 1
      ;;
  esac
}

# ─────────────────────────────────────────────
#  Homebrew kurulumu (macOS / Linux)
# ─────────────────────────────────────────────
install_brew() {
  if _has brew; then
    _ok "Homebrew zaten kurulu"
    return 0
  fi

  _step "Homebrew kuruluyor..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon path fix
  if [ "$DT_ARCH" = "arm64" ] && [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

# ─────────────────────────────────────────────
#  Starship prompt
#  Her platformda çalışır, shell-agnostic
# ─────────────────────────────────────────────
install_starship() {
  if _has starship; then
    _ok "Starship zaten kurulu ($(starship --version 2>/dev/null | head -1))"
    return 0
  fi

  _step "Starship kuruluyor..."

  if [ "$DT_OS" = "macos" ] && _has brew; then
    brew install starship
  elif _has brew; then
    # Linux'ta linuxbrew varsa
    brew install starship
  elif [ "$DT_IS_SSH" = "true" ] || ! _has sudo; then
    # SSH / sudo yok → home dizinine kur
    _info "sudo yok, ~/.local/bin dizinine kurulacak"
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://starship.rs/install.sh \
      | sh -s -- --bin-dir "$HOME/.local/bin" --yes
    export PATH="$HOME/.local/bin:$PATH"
  else
    # Sistem geneli kurulum
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
  fi
}

# ─────────────────────────────────────────────
#  fzf — fuzzy finder
# ─────────────────────────────────────────────
install_fzf() {
  if _has fzf; then
    _ok "fzf zaten kurulu"
    return 0
  fi

  _step "fzf kuruluyor..."

  if _has brew; then
    brew install fzf
    # key-bindings ve completion yükle
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
  else
    case "$DT_PKG_MGR" in
      apt)     pkg_install fzf ;;
      dnf|yum) pkg_install fzf ;;
      pacman)  pkg_install fzf ;;
      apk)     pkg_install fzf ;;
      *)
        # Git üzerinden kur
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --key-bindings --completion --no-update-rc
        ;;
    esac
  fi
}

# ─────────────────────────────────────────────
#  eza — modern ls (exa'nın devamı)
# ─────────────────────────────────────────────
install_eza() {
  if _has eza; then
    _ok "eza zaten kurulu"
    return 0
  fi

  _step "eza kuruluyor..."

  if _has brew; then
    brew install eza
  else
    case "$DT_PKG_MGR" in
      apt)
        # eza Ubuntu 22.04+ resmi repoda
        if _sudo apt-get install -y eza 2>/dev/null; then
          : # başarılı
        else
          # Eski Ubuntu: cargo ile derle
          _warn "eza apt'ta bulunamadı, binary indiriliyor..."
          _install_eza_binary
        fi
        ;;
      dnf|yum) pkg_install eza ;;
      pacman)  pkg_install eza ;;
      apk)
        _warn "apk'da eza yok, atlanıyor"
        return 0
        ;;
      *)
        _install_eza_binary
        ;;
    esac
  fi
}

_install_eza_binary() {
  local version arch url tmpdir
  version="$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
  arch="$DT_ARCH"  # arm64 | x86_64
  url="https://github.com/eza-community/eza/releases/download/v${version}/eza_${arch}-unknown-linux-gnu.tar.gz"
  tmpdir="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$tmpdir"
  mkdir -p "$HOME/.local/bin"
  mv "$tmpdir/eza" "$HOME/.local/bin/eza"
  chmod +x "$HOME/.local/bin/eza"
  rm -rf "$tmpdir"
  export PATH="$HOME/.local/bin:$PATH"
}

# ─────────────────────────────────────────────
#  zoxide — akıllı cd (z komutu)
# ─────────────────────────────────────────────
install_zoxide() {
  if _has zoxide; then
    _ok "zoxide zaten kurulu"
    return 0
  fi

  _step "zoxide kuruluyor..."

  if _has brew; then
    brew install zoxide
  else
    # Resmi installer her platformda çalışır
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

# ─────────────────────────────────────────────
#  Nerd Font (SSH ortamında atla)
# ─────────────────────────────────────────────
install_nerd_font() {
  if [ "$DT_IS_SSH" = "true" ]; then
    _info "SSH ortamı — font kurulumu atlandı (lokal terminale kurun)"
    return 0
  fi

  local font_name="${1:-JetBrainsMono}"
  local font_dir

  if [ "$DT_OS" = "macos" ]; then
    font_dir="$HOME/Library/Fonts"
  else
    font_dir="$HOME/.local/share/fonts"
  fi

  # Font zaten var mı?
  if find "$font_dir" -name "*${font_name}*" 2>/dev/null | grep -q .; then
    _ok "Nerd Font ($font_name) zaten kurulu"
    return 0
  fi

  _step "Nerd Font ($font_name) kuruluyor..."

  local version url tmpdir
  version="$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
    | grep '"tag_name"' | sed 's/.*"\(v[^"]*\)".*/\1/')"
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${font_name}.tar.xz"
  tmpdir="$(mktemp -d)"

  mkdir -p "$font_dir"
  curl -fsSL "$url" | tar -xJ -C "$tmpdir"
  cp "$tmpdir"/*.ttf "$font_dir/" 2>/dev/null || true
  cp "$tmpdir"/*.otf "$font_dir/" 2>/dev/null || true
  rm -rf "$tmpdir"

  # Font cache güncelle (Linux)
  if _has fc-cache; then
    fc-cache -fq "$font_dir"
  fi

  _ok "Nerd Font ($font_name) kuruldu → $font_dir"
}

# ─────────────────────────────────────────────
#  Tüm paketleri kur
#  SSH ortamında minimal set, lokal'de tam set
# ─────────────────────────────────────────────
install_all() {
  _step "Kurulum başlıyor — ortam: ${DT_OS}/${DT_TERM}/${DT_SHELL}"

  # macOS: önce brew
  if [ "$DT_OS" = "macos" ]; then
    install_brew
  fi

  # Temel araçlar — her ortamda
  install_starship
  install_fzf
  install_zoxide

  # SSH'ta sadece bunlar yeter
  if [ "$DT_IS_SSH" = "true" ]; then
    _info "SSH ortamı — minimal kurulum tamamlandı"
    return 0
  fi

  # Lokal terminalde ek araçlar
  install_eza
  install_nerd_font "JetBrainsMono"

  _ok "Tüm araçlar kuruldu"
}

# ─────────────────────────────────────────────
#  Kurulu araçları listele
# ─────────────────────────────────────────────
install_status() {
  local tools=("starship" "fzf" "eza" "zoxide" "git" "curl")
  echo ""
  echo "  ┌─ Araç Durumu ────────────────┐"
  for t in "${tools[@]}"; do
    if _has "$t"; then
      printf "  │  \033[32m✔\033[0m  %-12s %s\n" "$t" "$($t --version 2>/dev/null | head -1 | cut -c1-30)"
    else
      printf "  │  \033[31m✖\033[0m  %-12s %s\n" "$t" "kurulu değil"
    fi
  done
  echo "  └──────────────────────────────┘"
  echo ""
}

# ─────────────────────────────────────────────
#  Script doğrudan çalıştırılırsa install_all
#  source edilirse sessiz kal (bash + zsh uyumlu)
# ─────────────────────────────────────────────
if [ -n "${BASH_VERSION:-}" ]; then
  [ "${BASH_SOURCE[0]}" = "$0" ] && { install_all; install_status; }
elif [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in
    *:file*) : ;;                              # source edildi → sessiz
    *)       install_all; install_status ;;    # doğrudan çalıştırıldı
  esac
fi
