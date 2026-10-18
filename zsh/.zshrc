# ~/.dotfiles/zsh/.zshrc

# ── Koruma: yalnızca zsh içindir ────────────────────────────────────────────
# bash'te `source ~/.zshrc` çalıştırılırsa hata vermeden sessizce çık.
if [ -z "${ZSH_VERSION:-}" ]; then
  return 0 2>/dev/null || exit 0
fi

# ── Performans: başlangıç süresi ölçümü ───────────────────────────────────────
# Aktifleştirmek için: ZPROF=1 zsh
[[ -n "$ZPROF" ]] && zmodload zsh/zprof

# ── Temel zsh ayarları ────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # tekrar eden komutları kaydetme
setopt HIST_IGNORE_SPACE      # boşlukla başlayanları kaydetme
setopt SHARE_HISTORY          # terminaller arası geçmişi paylaş
setopt AUTO_CD                # dizin adı yazınca cd
setopt CORRECT                # yazım hatası önerisi
setopt GLOB_DOTS              # ls * ile gizli dosyaları da göster
setopt NO_BEEP                # bip sesi yok

# ── Completion ────────────────────────────────────────────────────────────────
autoload -Uz compinit
# Günde bir kez yenile (her açılışta yenileme yavas olur)
if [[ -f "$HOME/.zcompdump" && $(find "$HOME/.zcompdump" -mtime +1 2>/dev/null) ]]; then
  compinit
else
  compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # büyük/küçük harf
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# ── Dotfiles tema yükleyici ───────────────────────────────────────────────────
# dotfiles:theme
[ -f "$HOME/.dotfiles/lib/theme.sh" ] && source "$HOME/.dotfiles/lib/theme.sh"

# ── Yerel override (git'e commit etme) ───────────────────────────────────────
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ── Profil çıktısı ────────────────────────────────────────────────────────────
if [[ -n "${ZPROF:-}" ]]; then zprof; fi
