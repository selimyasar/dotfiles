# Kurulum ve Kullanım Notu

Kısa referans. Ayrıntılı dokümantasyon: [README.md](README.md).

## Kurulum

```bash
# Tek komut
curl -fsSL https://raw.githubusercontent.com/selimyasar/dotfiles/main/setup.sh | bash

# Önce ne yapacağını gör (hiçbir şeyi değiştirmez)
bash setup.sh --dry-run

# SSH / kısıtlı ortam (sudo gerekmez, ~/.local/bin'e kurar)
curl -fsSL https://raw.githubusercontent.com/selimyasar/dotfiles/main/setup.sh | bash -s -- --minimal
```

Seçenekler: `--dry-run` · `--minimal` · `--force` · `--no-font` · `--repo=URL`
Env: `DOTFILES_DIR` (varsayılan `~/.dotfiles`) · `DOTFILES_REPO` · `DOTFILES_BRANCH` (`main`)

## Etkinleştirme

```bash
source ~/.zshrc        # veya: exec zsh / yeni terminal
```

## Kontrol

```bash
bash ~/.dotfiles/lib/detect.sh                      # ortam + görünüm raporu
source ~/.dotfiles/lib/install.sh && install_status # araç durumu
```

## Kullanım

- **Araçlar:** starship (prompt) · fzf (`Ctrl+R` geçmiş, `Ctrl+T` dosya) · zoxide (`z proje`) · eza (`ls`/`ll`/`la`/`lt`)
- **Git:** `g` `gs` `ga` `gc` `gp` `gl` `gd`
- **Gezinme:** `..` `...`
- **Yerel override:** `~/.zshrc.local`, `~/.bashrc.local` (repodan hariç)

## Görünüm (light/dark)

- Görünüm otomatik algılanır (macOS `AppleInterfaceStyle` veya `COLORFGBG`).
- Zorlamak için: `export DOTFILES_THEME_MODE=light` (veya `dark`)
- Terminalin arka plan/ön plan rengini de tema yazsın: `export DOTFILES_FORCE_BG=1`
- Çıkışta palet sıfırlamayı kapat: `export DOTFILES_RESET_COLORS=0`
- macOS'ta sistem teması değişince açık terminallerde prompt otomatik tazelenir.

## Güncelleme

Kurulum scriptini tekrar çalıştırmak yeterlidir (idempotent):

```bash
bash ~/.dotfiles/setup.sh
```
