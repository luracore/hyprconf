# Hyprconf

Configurações pessoais do meu ambiente Arch Linux + Hyprland.

## Dependências

```bash
sudo pacman -S kitty hyprland \
    hyprpolkitagent hyprlock hypridle hyprlauncher hyprshot \
    wl-clipboard power-profiles-daemon \
    ttf-jetbrains-mono-nerd starship \
    dolphin kio-admin ark \
    networkmanager bluez bluez-utils
```

```bash
yay -S wayle-bin
```

## Instalação

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

## Atalhos

### Aplicações

| Atalho | Ação |
|---|---|
| `SUPER + W` | Abrir terminal |
| `SUPER + E` | Abrir gerenciador de arquivos |
| `SUPER + SPACE` | Abrir launcher |
| `SUPER + P` | Bloquear tela |
| `SUPER + SHIFT + P` | Sair do Hyprland |
| `SUPER + S` | Screenshot da janela |
| `SUPER + SHIFT + S` | Screenshot de região |

### Janelas

| Atalho | Ação |
|---|---|
| `SUPER + Q` | Fechar janela |
| `SUPER + V` | Alternar floating |
| `SUPER + A` | Alternar split |
| `SUPER + F` | Alternar maximização |
| `SUPER + SHIFT + F` | Alternar fullscreen |

### Navegação

| Atalho | Ação |
|---|---|
| `SUPER + H` | Foco para esquerda |
| `SUPER + L` | Foco para direita |
| `SUPER + K` | Foco para cima |
| `SUPER + J` | Foco para baixo |
| `SUPER + SHIFT + H` | Mover janela para esquerda |
| `SUPER + SHIFT + L` | Mover janela para direita |
| `SUPER + SHIFT + K` | Mover janela para cima |
| `SUPER + SHIFT + J` | Mover janela para baixo |

### Workspaces

| Atalho | Ação |
|---|---|
| `SUPER + 1–9` | Ir para workspace |
| `SUPER + SHIFT + 1–9` | Mover janela para workspace |

## Configurações adicionais

### Ativar serviços:

```bash
echo 'eval "$(starship init bash)"' >> ~/.bashrc
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon.service
wpctl settings --save bluetooth.autoswitch-to-headset-profile false
```
