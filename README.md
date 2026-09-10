# Hyprconf

Configurações pessoais do meu ambiente Arch Linux + Hyprland.

## Dependências*

```bash
sudo pacman -S kitty hyprland \
    hyprlock hypridle hyprlauncher hyprshot wtype \
    wayle ttf-jetbrains-mono-nerd starship \
    thunar gvfs thunar-volman tumbler \
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
ln -s ~/hyprconf/rofi ~/.config/rofi
ln -s ~/hyprconf/wayle ~/.config/wayle
ln -s ~/hyprconf/starship.toml ~/.config/starship.toml
```

Após isso, as configurações ficam versionadas em `~/hyprconf`, enquanto os programas continuam acessando os arquivos através de `~/.config`.

## Serviços

Ativar o NetworkManager e o Bluetooth:

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
```

## .bashrc
```bash
echo 'eval "$(starship init bash)"' >> ~/.bashrc
```
