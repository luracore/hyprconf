# Hyprconf

Meu ambiente **Arch Linux + Hyprland**: barra, lançador, seletor de
wallpaper e tema, gerenciador de pacotes e configurações feitos em Quickshell,
com um tema de cores que vale para o sistema todo.

## Dependencias:

sudo pacman -S --needed \
    hyprland hyprlock hypridle hyprshot \
    hyprpolkitagent xdg-desktop-portal-hyprland \
    xdg-utils wl-clipboard libnotify \
    quickshell awww imagemagick cava curl jq nodejs \
    gvfs qt6ct adw-gtk-theme papirus-icon-theme \
    librsvg xorg-xcursorgen \
    ttf-firacode-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk \
    pipewire-pulse libpulse wireplumber playerctl \
    networkmanager nm-connection-editor bluez bluez-utils \
    upower power-profiles-daemon ddcutil hyprsunset brightnessctl \
    fzf pacman-contrib git

### Serviços

Rede, Bluetooth, bateria e perfis de energia usados pela barra:

sudo systemctl enable --now \
    NetworkManager bluetooth upower power-profiles-daemon

### Programas padrão

Estes são os aplicativos utilizados ou recomendados pelo ambiente.
Você pode substituí-los pelos de sua preferência:

sudo pacman -S --needed \
    foot thunar thunar-archive-plugin tumbler \
    file-roller neovim npm unzip ripgrep \
    tree-sitter-cli gcc clang firefox opencode

Para o Thunar abrir as pastas:

xdg-mime default thunar.desktop inode/directory

## Instalação

Clone o repositório e execute o instalador:

```bash
git clone https://github.com/luracore/hyprconf ~/hyprconf
~/hyprconf/install.sh
```

## Desinstalação

```bash
~/hyprconf/uninstall.sh
```

Remove os links, devolve o backup mais recente de cada um ao lugar, volta o
gsettings ao padrão e desfaz os ajustes do Flatpak e do áudio do Bluetooth.

## Uso

- `SUPER + SPACE` abre o lançador de aplicativos.
- O **HyprSettings** (no lançador) leva a tudo que dá para mudar:
  wallpapers, temas, atalhos, programas padrão, pacotes, monitores, aparência
  e o que abre com o Hyprland.
