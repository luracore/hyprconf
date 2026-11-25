# Hyprconf

Meu ambiente **Arch Linux + Hyprland**: barra, lançador, seletor de wallpaper e tema, gerenciador de pacotes e configurações feitos em Quickshell, com um tema de cores que vale para o sistema todo.

## Instalação

Clone o repositório e execute o instalador:

```bash
git clone https://github.com/luracore/hyprconf ~/hyprconf
~/hyprconf/install.sh
```

O instalador instala as dependências necessárias e configura o ambiente.

### Opções do instalador

| Parâmetro | Função |
|---|---|
| `--bkp` | Faz backup das configurações existentes (padrão). |
| `--no-bkp` | Remove as configurações existentes em vez de fazer backup. |
| `--defaults` | Instala os programas padrão (padrão). |
| `--no-defaults` | Não instala os programas padrão. |

## Serviços

Rede, Bluetooth, bateria e perfis de energia utilizados pela barra:

```bash
sudo systemctl enable --now \
    NetworkManager bluetooth upower power-profiles-daemon
```

Para o Thunar abrir as pastas:

```bash
xdg-mime default thunar.desktop inode/directory
```

## Uso

- `SUPER + SPACE` abre o lançador de aplicativos.
- O **HyprSettings**, disponível no lançador, dá acesso às configurações do ambiente: wallpapers, temas, atalhos, programas padrão, pacotes, monitores, aparência e inicialização de aplicativos.

