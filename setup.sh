#!/usr/bin/env bash
# setup.sh — dotfiles ana kurulum scripti
# Kullanım:
#   curl -fsSL https://raw.githubusercontent.com/selimyasar/dotfiles/main/setup.sh | bash
#   veya klonladıktan sonra: bash ~/.dotfiles/setup.sh
#
# Seçenekler:
#   --dry-run    Neyin yapılacağını göster, kurma
#   --minimal    Sadece starship + fzf + config (SSH için)
#   --force      Mevcut dosyaların üstüne yaz
#   --no-font    Font kurma
#   --repo URL   Dotfiles repo adresi (varsayılan: DOTFILES_REPO)

set -euo pipefail

# ─────────────────────────────────────────────
#  Sabitler
# ─────────────────────────────────────────────
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/selimyasar/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
LOG_FILE="${TMPDIR:-/tmp}/dotfiles-setup-$(date +%Y%m%d-%H%M%S).log"

# ─────────────────────────────────────────────
#  Argüman ayrıştırma
# ─────────────────────────────────────────────
OPT_DRY_RUN=false
OPT_MINIMAL=false
OPT_FORCE=false
OPT_NO_FONT=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)  OPT_DRY_RUN=true  ;;
    --minimal)  OPT_MINIMAL=true  ;;
    --force)    OPT_FORCE=true    ;;
    --no-font)  OPT_NO_FONT=true  ;;
    --repo=*)   DOTFILES_REPO="${arg#*=}" ;;
    --help|-h)
      cat <<EOF
Kullanım: setup.sh [seçenekler]

Seçenekler:
  --dry-run    Neyin yapılacağını göster, kurma
  --minimal    Sadece core araçlar (SSH için ideal)
  --force      Mevcut symlink/config'lerin üstüne yaz
  --no-font    Nerd Font kurulumunu atla
  --repo=URL   Dotfiles git repo adresi

Ortam değişkenleri:
  DOTFILES_DIR    Kurulum dizini (varsayılan: ~/.dotfiles)
  DOTFILES_REPO   Git repo adresi
  DOTFILES_BRANCH Git branch (varsayılan: main)
EOF
      exit 0
      ;;
    *)
      echo "Bilinmeyen seçenek: $arg (--help için yardım)" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────
#  Çıktı & loglama
# ─────────────────────────────────────────────
exec > >(tee -a "$LOG_FILE") 2>&1

_c()    { printf '\033[%sm' "$1"; }
_reset(){ printf '\033[0m'; }

_banner() {
  echo ""
  echo "$(_c 35)  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗$(_reset)"
  echo "$(_c 35)  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝$(_reset)"
  echo "$(_c 35)  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗$(_reset)"
  echo "$(_c 35)  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║$(_reset)"
  echo "$(_c 35)  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║$(_reset)"
  echo "$(_c 35)  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝$(_reset)"
  echo ""
}

_step()    { echo "";    printf "$(_c 1)$(_c 34)▶  %s$(_reset)\n" "$*"; }
_ok()      { printf "    $(_c 32)✔$(_reset)  %s\n" "$*"; }
_info()    { printf "    $(_c 34)ℹ$(_reset)  %s\n" "$*"; }
_warn()    { printf "    $(_c 33)⚠$(_reset)  %s\n" "$*"; }
_err()     { printf "    $(_c 31)✖$(_reset)  %s\n" "$*" >&2; }
_dry()     { printf "    $(_c 33)~$(_reset)  [dry-run] %s\n" "$*"; }

_run() {
  # Komutları dry-run modunda göster, gerçekte çalıştırma
  if [ "$OPT_DRY_RUN" = "true" ]; then
    _dry "$*"
    return 0
  fi
  "$@"
}

# ─────────────────────────────────────────────
#  Hata yönetimi — başarısız adımı yakala
# ─────────────────────────────────────────────
_on_error() {
  local line="$1"
  _err "Satır $line'da hata oluştu. Log: $LOG_FILE"
  exit 1
}
trap '_on_error $LINENO' ERR

# ─────────────────────────────────────────────
#  Ön koşul kontrolü
# ─────────────────────────────────────────────
_check_prerequisites() {
  _step "Ön koşullar kontrol ediliyor"

  local missing=()
  for cmd in curl git bash; do
    if command -v "$cmd" &>/dev/null; then
      _ok "$cmd mevcut"
    else
      missing+=("$cmd")
      _err "$cmd bulunamadı"
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    _err "Eksik araçlar: ${missing[*]}"
    _err "Lütfen önce bunları kurun ve tekrar deneyin."
    exit 1
  fi

  # bash sürüm kontrolü (macOS'ta eski bash var)
  local bash_major
  bash_major="${BASH_VERSINFO[0]:-0}"
  if [ "$bash_major" -lt 4 ]; then
    _warn "Bash $bash_major.x — bazı özellikler çalışmayabilir (öneri: bash 5+)"
  else
    _ok "Bash $BASH_VERSION"
  fi
}

# ─────────────────────────────────────────────
#  Repo klonla / güncelle
# ─────────────────────────────────────────────
_clone_or_update_repo() {
  _step "Dotfiles reposu"

  if [ -d "$DOTFILES_DIR/.git" ]; then
    _info "Repo zaten mevcut → güncelleniyor ($DOTFILES_DIR)"
    _run git -C "$DOTFILES_DIR" pull --ff-only origin "$DOTFILES_BRANCH" \
      || _warn "Git pull başarısız — yerel değişiklikler var olabilir, devam ediliyor"
    _ok "Repo güncellendi"
  elif [ -d "$DOTFILES_DIR" ] && [ "$OPT_FORCE" = "false" ]; then
    _warn "$DOTFILES_DIR mevcut ama git reposu değil"
    _warn "Üstüne yazmak için --force kullanın"
  else
    _info "$DOTFILES_DIR dizinine klonlanıyor..."
    _run git clone --depth 1 \
      --branch "$DOTFILES_BRANCH" \
      "$DOTFILES_REPO" \
      "$DOTFILES_DIR"
    _ok "Repo klonlandı"
  fi
}

# ─────────────────────────────────────────────
#  Araçları kur
# ─────────────────────────────────────────────
_install_tools() {
  _step "Araçlar kuruluyor"

  # shellcheck disable=SC1091
  source "$DOTFILES_DIR/lib/detect.sh"
  detect_all

  # shellcheck disable=SC1091
  source "$DOTFILES_DIR/lib/install.sh"

  if [ "$OPT_MINIMAL" = "true" ] || [ "$DT_IS_SSH" = "true" ]; then
    _info "Minimal mod — temel araçlar: starship, fzf, zoxide"
    _run install_starship
    _run install_fzf
    _run install_zoxide
  else
    _run install_all

    if [ "$OPT_NO_FONT" = "false" ]; then
      _run install_nerd_font "JetBrainsMono"
    else
      _info "Font kurulumu atlandı (--no-font)"
    fi
  fi
}

# ─────────────────────────────────────────────
#  Symlink yönetimi
# ─────────────────────────────────────────────
_symlink() {
  local src="$1"
  local dst="$2"

  if [ ! -e "$src" ]; then
    _warn "Kaynak bulunamadı, atlandı: $src"
    return 0
  fi

  if [ "$OPT_DRY_RUN" = "true" ]; then
    _dry "symlink: $src → $dst"
    return 0
  fi

  # Hedef zaten doğru symlink mi?
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    _ok "Zaten bağlı: $dst"
    return 0
  fi

  # Mevcut dosyayı yedekle
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$OPT_FORCE" = "true" ]; then
      local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
      mv "$dst" "$backup"
      _warn "Yedeklendi: $backup"
    else
      _warn "Mevcut dosya var, atlandı: $dst (--force ile üstüne yaz)"
      return 0
    fi
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  _ok "Bağlandı: $dst → $src"
}

_link_configs() {
  _step "Config dosyaları bağlanıyor"

  # Shell config'leri
  _symlink "$DOTFILES_DIR/zsh/.zshrc"        "$HOME/.zshrc"
  _symlink "$DOTFILES_DIR/bash/.bashrc"       "$HOME/.bashrc"
  _symlink "$DOTFILES_DIR/bash/.bash_profile" "$HOME/.bash_profile"

  # Starship ana config (fallback)
  _symlink "$DOTFILES_DIR/starship.toml"      "$HOME/.config/starship.toml"

  # Starship profilleri
  mkdir -p "$HOME/.config/dotfiles-themes"
  for toml in "$DOTFILES_DIR/themes"/*.toml; do
    [ -f "$toml" ] || continue
    _symlink "$toml" "$HOME/.config/dotfiles-themes/$(basename "$toml")"
  done

  # Git global config
  _symlink "$DOTFILES_DIR/git/.gitconfig"     "$HOME/.gitconfig"
  _symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"

  # Editör config'leri (varsa)
  [ -d "$DOTFILES_DIR/nvim" ] && \
    _symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
  [ -d "$DOTFILES_DIR/tmux" ] && \
    _symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
}

# ─────────────────────────────────────────────
#  Shell RC dosyasına theme.sh satırı ekle
# ─────────────────────────────────────────────
_inject_theme_loader() {
  _step "Shell config güncelleniyor"

  local inject_line='[ -f "$HOME/.dotfiles/lib/theme.sh" ] && source "$HOME/.dotfiles/lib/theme.sh"'
  local marker="# dotfiles:theme"

  # Hangi RC dosyaları hedeflenmeli?
  local rc_files=()

  # detect.sh zaten source edildi (install_tools içinde)
  case "$DT_SHELL" in
    zsh)
      rc_files=("$HOME/.zshrc")
      ;;
    bash)
      rc_files=("$HOME/.bashrc" "$HOME/.bash_profile")
      ;;
    *)
      # Her ikisine de ekle
      rc_files=("$HOME/.zshrc" "$HOME/.bashrc")
      ;;
  esac

  for rc in "${rc_files[@]}"; do
    if [ "$OPT_DRY_RUN" = "true" ]; then
      _dry "Eklenecek → $rc: $inject_line"
      continue
    fi

    # Zaten eklendi mi?
    if grep -qF "$marker" "$rc" 2>/dev/null; then
      _ok "Zaten ekli: $rc"
      continue
    fi

    # Dosya yoksa oluştur
    touch "$rc"

    printf '\n%s\n%s\n' "$marker" "$inject_line" >> "$rc"
    _ok "Eklendi: $rc"
  done
}

# ─────────────────────────────────────────────
#  Git global ayarları (ilk kurulumda)
# ─────────────────────────────────────────────
_configure_git() {
  _step "Git yapılandırması"

  # İsim/email yoksa sor
  local git_name git_email
  git_name="$(git config --global user.name 2>/dev/null || true)"
  git_email="$(git config --global user.email 2>/dev/null || true)"

  if [ -z "$git_name" ] && [ -t 0 ]; then
    printf "    Git kullanıcı adı: "
    read -r git_name
    [ -n "$git_name" ] && _run git config --global user.name "$git_name"
  fi

  if [ -z "$git_email" ] && [ -t 0 ]; then
    printf "    Git e-posta: "
    read -r git_email
    [ -n "$git_email" ] && _run git config --global user.email "$git_email"
  fi

  # Genel git ayarları
  _run git config --global core.editor "${EDITOR:-vim}"
  _run git config --global core.excludesfile "$HOME/.gitignore_global"
  _run git config --global init.defaultBranch main
  _run git config --global pull.rebase false
  _run git config --global fetch.prune true
  _run git config --global rebase.autoStash true
  _run git config --global color.ui auto

  # Delta varsa diff pager olarak ayarla
  if command -v delta &>/dev/null; then
    _run git config --global core.pager delta
    _run git config --global interactive.diffFilter "delta --color-only"
    _run git config --global delta.navigate true
    _run git config --global delta.side-by-side true
    _ok "delta: git diff pager olarak ayarlandı"
  fi

  _ok "Git yapılandırması tamamlandı"
}

# ─────────────────────────────────────────────
#  Kurulum özeti
# ─────────────────────────────────────────────
_print_summary() {
  local shell_reload
  case "$DT_SHELL" in
    zsh)  shell_reload="source ~/.zshrc" ;;
    bash) shell_reload="source ~/.bashrc" ;;
    *)    shell_reload="yeni terminal aç" ;;
  esac

  echo ""
  echo "  $(_c 32)┌─ Kurulum Tamamlandı ─────────────────────────┐$(_reset)"
  echo "  $(_c 32)│$(_reset)"
  printf "  $(_c 32)│$(_reset)  %-20s $(_c 32)%s$(_reset)\n" "Dotfiles dizini:" "$DOTFILES_DIR"
  printf "  $(_c 32)│$(_reset)  %-20s $(_c 32)%s$(_reset)\n" "Log dosyası:" "$LOG_FILE"
  printf "  $(_c 32)│$(_reset)  %-20s $(_c 32)%s$(_reset)\n" "Ortam:" "$DT_OS / $DT_SHELL / $DT_TERM"
  echo "  $(_c 32)│$(_reset)"
  echo "  $(_c 32)│$(_reset)  Temayı aktifleştirmek için:"
  echo "  $(_c 32)│$(_reset)"
  printf "  $(_c 32)│$(_reset)    $(_c 33)%s$(_reset)\n" "$shell_reload"
  echo "  $(_c 32)│$(_reset)"
  echo "  $(_c 32)│$(_reset)  Araç durumunu görmek için:"
  echo "  $(_c 32)│$(_reset)"
  printf "  $(_c 32)│$(_reset)    $(_c 33)%s$(_reset)\n" "bash $DOTFILES_DIR/lib/install.sh status"
  echo "  $(_c 32)│$(_reset)"
  echo "  $(_c 32)│$(_reset)  Ortam tespitini görmek için:"
  echo "  $(_c 32)│$(_reset)"
  printf "  $(_c 32)│$(_reset)    $(_c 33)%s$(_reset)\n" "bash $DOTFILES_DIR/lib/detect.sh"
  echo "  $(_c 32)│$(_reset)"
  echo "  $(_c 32)└──────────────────────────────────────────────┘$(_reset)"
  echo ""
}

# ─────────────────────────────────────────────
#  Ana akış
# ─────────────────────────────────────────────
main() {
  _banner

  [ "$OPT_DRY_RUN" = "true" ] && \
    _warn "DRY-RUN modu — hiçbir şey kurulmayacak\n"

  _check_prerequisites
  _clone_or_update_repo
  _install_tools
  _link_configs
  _inject_theme_loader
  _configure_git
  _print_summary
}

main "$@"
