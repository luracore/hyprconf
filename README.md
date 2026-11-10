# Hyprconf

Configurações pessoais do meu ambiente **Arch Linux + Hyprland (Wayland)**.

## Estrutura

```text
hyprconf/
├── install.sh                # cria os links e ativa os serviços
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
├── quickshell/
│   ├── bar/                  # barra (iniciada pelo startup.lua)
│   └── wallpaper-picker/     # seletor de wallpaper
├── Themes/                   # temas da barra (*.json) + current (symlink)
└── Wallpapers/               # imagens + current (symlink)
```

## Dependências

O `install.sh` **não** instala pacotes: ele só cria os links e ativa os serviços.
Instale as dependências antes, com o sistema atualizado (as configs assumem a
versão mais recente de cada pacote):

```bash
sudo pacman -Syu --needed \
  hyprland hyprlock hypridle hyprshot hyprlauncher hyprpolkitagent \
  xdg-desktop-portal-hyprland \
  foot dolphin ark kio-admin \
  quickshell awww imagemagick cava curl \
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

## Temas

A barra lê o tema de `Themes/current`, um symlink para um dos `.json` da pasta.
Para trocar (a barra recarrega sozinha):

```bash
ln -sfn TokyoNight.json ~/hyprconf/Themes/current
```

Temas disponíveis: `OsakaJade`, `Retro82`, `TokyoNight`.
