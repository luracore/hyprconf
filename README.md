# Hyprconf

Configurações pessoais do meu ambiente **Arch Linux + Hyprland (Wayland)**.

## Estrutura

```text
hyprconf/
├── install.sh                # instala dependências e cria os links
├── hypr/
│   ├── hyprland.lua          # carrega config/*.lua
│   ├── hypridle.conf
│   ├── hyprlock.conf
│   └── config/
│       ├── animations.lua
│       ├── appearance.lua
│       ├── binds.lua
│       ├── input.lua
│       ├── layout.lua
│       ├── monitor.lua
│       ├── startup.lua
│       └── window-rules.lua
├── foot/
├── quickshell/               # programas em quickshell
├── Wallpapers/               # imagens + current (symlink)
```

## Dependências

```bash
sudo pacman -S --needed \
  hyprland hyprlock hypridle hyprshot hyprlauncher hyprpolkitagent \
  xdg-desktop-portal-hyprland \
  foot dolphin ark kio-admin \
  quickshell awww imagemagick \
  pipewire-pulse wireplumber playerctl \
  ddcutil \
  opencode \
  networkmanager bluez bluez-utils \
  git
```

## Instalação

```bash
cd ~
git clone https://github.com/luracore/hyprconf
cd hyprconf
./install.sh
```
