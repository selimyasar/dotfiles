# dotfiles

Farklı ortamlarda (macOS iTerm2, Linux, SSH) terminal açıldığında otomatik olarak tema ve araçları yükleyen, tek komutla kurulum yapan dotfiles sistemi.

---

## Ne yapar?

Yeni bir makineye ya da SSH sunucusuna bağlandığında aşağıdakileri otomatik olarak halleder:

- Ortamı tespit eder (macOS/Linux/WSL, iTerm2/SSH/tmux, zsh/bash)
- Starship, fzf, zoxide, eza gibi araçları kurar
- Ortama uygun prompt ve renk teması seçer
- Config dosyalarını symlink ederek bağlar
- Her şeyi idempotent çalıştırır — defalarca çalıştırsan da bir şeyi bozmaz

---

## Hızlı başlangıç

```bash
curl -fsSL https://raw.githubusercontent.com/KULLANICI/dotfiles/main/setup.sh | bash
```

Önce ne yapacağını görmek istersen:

```bash
bash setup.sh --dry-run
```

SSH sunucusu veya kısıtlı ortam için minimal mod:

```bash
curl -fsSL .../setup.sh | bash -s -- --minimal
```

---

## Dosya yapısı

```
~/.dotfiles/
├── setup.sh                   # Ana kurulum scripti
├── starship.toml              # Starship fallback config
│
├── lib/
│   ├── detect.sh              # Ortam tespit kütüphanesi
│   ├── install.sh             # Paket kurulum kütüphanesi
│   └── theme.sh               # Terminal açıldığında çalışan yükleyici
│
├── themes/
│   ├── starship-full.toml     # Lokal terminal — truecolor + Nerd Font
│   ├── starship-ssh.toml      # SSH — ASCII semboller, hızlı
│   └── starship-tmux.toml     # Tmux — kompakt, tek satır
│
├── zsh/
│   └── .zshrc
├── bash/
│   ├── .bashrc
│   └── .bash_profile
└── git/
    ├── .gitconfig
    └── .gitignore_global
```

---

## Nasıl çalışır?

### 1. Ortam tespiti — `lib/detect.sh`

Her terminal açılışında önce ortam tespit edilir. Ürettiği değişkenler diğer scriptler tarafından kullanılır.

| Değişken | Olası değerler |
|---|---|
| `DT_OS` | `macos` · `linux` · `wsl` |
| `DT_DISTRO` | `ubuntu` · `arch` · `fedora` · ... |
| `DT_PKG_MGR` | `brew` · `apt` · `dnf` · `pacman` · `apk` |
| `DT_SHELL` | `zsh` · `bash` · `fish` |
| `DT_TERM` | `iterm2` · `wezterm` · `kitty` · `ssh` · `gnome` |
| `DT_IS_SSH` | `true` · `false` |
| `DT_IS_TMUX` | `true` · `false` |
| `DT_COLOR_SUPPORT` | `truecolor` · `256` · `basic` · `none` |
| `DT_ARCH` | `arm64` · `x86_64` |

Ortam raporunu görmek için:

```bash
bash ~/.dotfiles/lib/detect.sh
```

### 2. Kurulum — `lib/install.sh`

OS ve paket yöneticisine göre araçları kurar. `sudo` yoksa `~/.local/bin` dizinine kurar. SSH ortamında sadece temel araçları yükler, font ve masaüstü araçlarını atlar.

| Araç | Ne yapar | SSH'ta |
|---|---|---|
| [starship](https://starship.rs) | Shell-agnostic akıllı prompt | ✔ kurulur |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder, `Ctrl+R` geçmiş | ✔ kurulur |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Akıllı `cd` — `z proje` yeter | ✔ kurulur |
| [eza](https://github.com/eza-community/eza) | Modern, renkli `ls` | ✖ atlanır |
| JetBrainsMono Nerd Font | İkon desteği | ✖ atlanır |

Araç durumunu görmek için:

```bash
source ~/.dotfiles/lib/install.sh && install_status
```

### 3. Tema yükleme — `lib/theme.sh`

Her terminal açıldığında `.zshrc` / `.bashrc` üzerinden çalışır. Ortama göre doğru starship profilini seçer, renk şemasını uygular, alias'ları ve araçları yükler.

```
Terminal açıldı
    │
    ├─ PATH, EDITOR, genel alias'lar
    ├─ OSC escape → Tokyonight renk paleti
    ├─ Başlık hook (SSH'ta user@host gösterir)
    ├─ fzf → Ctrl+R, tema uyumlu renkler
    ├─ zoxide → z komutu
    ├─ eza → ls / ll / la / lt alias'ları
    ├─ starship → ortama göre profil seçimi
    └─ SSH'taysa bağlantı bilgisi satırı
```

#### Starship profil seçimi

```
DT_IS_SSH = true       →  starship-ssh.toml    (ASCII, kullanıcı@host)
DT_IS_TMUX = true      →  starship-tmux.toml   (tek satır, kompakt)
DT_COLOR_SUPPORT = truecolor  →  starship-full.toml  (ikonlar, dil versiyonları)
diğer                  →  starship-minimal.toml
```

---

## Kurulum seçenekleri

```
Seçenek          Açıklama
─────────────    ──────────────────────────────────────────────────
--dry-run        Neyin yapılacağını göster, hiçbir şeyi değiştirme
--minimal        Sadece temel araçlar (SSH için)
--force          Mevcut config dosyalarının üstüne yaz
--no-font        Nerd Font kurulumunu atla
--repo=URL       Farklı bir dotfiles repo adresi kullan
```

---

## Ortam değişkenleri

```bash
DOTFILES_DIR     # Kurulum dizini (varsayılan: ~/.dotfiles)
DOTFILES_REPO    # Git repo adresi
DOTFILES_BRANCH  # Branch adı (varsayılan: main)
```

---

## Yeni makineye kurulum adımları

```bash
# 1. Kur
curl -fsSL https://raw.githubusercontent.com/KULLANICI/dotfiles/main/setup.sh | bash

# 2. Shell'i yenile
source ~/.zshrc   # veya: exec zsh

# 3. Kontrol et
bash ~/.dotfiles/lib/detect.sh
```

### SSH sunucusuna kurulum

```bash
# Minimal mod — sudo gerekmez, ~/.local/bin dizinine kurar
curl -fsSL .../setup.sh | bash -s -- --minimal

# Veya sshrc ile hiç sunucuya kurulum yapmadan çalıştır
# https://github.com/Russell91/sshrc
```

---

## Alias referansı

### Dosya gezgini

```bash
ls    # eza — ikonlu, gruplu
ll    # eza -l — git durumu, göreceli tarih
la    # eza -la — gizli dosyalar dahil
lt    # eza --tree --level=2
lta   # eza --tree --level=3 (node_modules hariç)
```

### Git

```bash
g     # git
gs    # git status
ga    # git add
gc    # git commit
gp    # git push
gl    # git log --oneline --graph -15
gd    # git diff
```

### Navigasyon

```bash
z proje          # zoxide: sık gidilen dizine atla
..               # cd ..
...              # cd ../..
Ctrl+R           # fzf: geçmiş arama
Ctrl+T           # fzf: dosya arama
```

---

## Tema

Renk şeması: [Tokyonight](https://github.com/folke/tokyonight.nvim)

OSC 4 escape dizileri ile terminal emülatörün ANSI paletine doğrudan yazılır — terminal uygulamasında ayrı bir tema kurmana gerek kalmaz.

---

## Yerel override

Git'e commit etmeden kişisel ayar eklemek için:

```bash
# Shell override
~/.zshrc.local    # zsh için
~/.bashrc.local   # bash için
```

Bu dosyalar varsa otomatik yüklenir, repodan dışlanır.

---

## Katkı & geliştirme

Yeni bir terminal emülatör desteği eklemek için `lib/detect.sh` içindeki `detect_terminal()` fonksiyonuna yeni `elif` dalı eklemen yeterli. Yeni bir starship profili için `themes/` altına `.toml` dosyası ekle, `lib/theme.sh` içindeki `_load_starship()` fonksiyonunda hangi koşulda seçileceğini belirt.
