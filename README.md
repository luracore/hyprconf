# Hyprconf

Configurações pessoais do meu ambiente Arch Linux + Hyprland.

## Dependências*

```bash
sudo pacman -S kitty hyprland \
    hyprpolkitagent hyprlock hypridle hyprlauncher hyprshot \
    wayle power-profiles-daemon \
    wl-clipboard ttf-jetbrains-mono-nerd starship \
    dolphin kio-admin ark \
    networkmanager bluez bluez-utils
```

## Clonar repositório

Clonar o repositório diretamente na HOME:

```bash
cd ~
git clone https://github.com/luracore/hyprconf
cd hyprconf
```

## Configuração

Criar o diretório de configuração e os links simbólicos:

```bash
mkdir -p ~/.config

ln -s ~/hyprconf/hypr ~/.config/hypr
ln -s ~/hyprconf/kitty ~/.config/kitty
mv ~/.config/wayle ~/.config/wayle.default
ln -s ~/hyprconf/wayle ~/.config/wayle
ln -s ~/hyprconf/starship.toml ~/.config/starship.toml
```

Após isso, as configurações ficam versionadas em `~/hyprconf`, enquanto os programas continuam acessando os arquivos através de `~/.config`.

## Serviços

Ativar serviços:

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon.service
```

## .bashrc
```bash
echo 'eval "$(starship init bash)"' >> ~/.bashrc
```

## Impedir troca automática de perfil bluetooth
```bash
wpctl settings --save bluetooth.autoswitch-to-headset-profile false
```
