# Hyprconf

Configurações pessoais do meu ambiente Arch Linux + Hyprland.

## Dependências*

```bash
sudo pacman -S kitty hyprland \
    hyprlock hypridle hyprlauncher hyprshot wtype \
    wayle power-profiles-daemon ttf-jetbrains-mono-nerd starship \
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
