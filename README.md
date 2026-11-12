# Hyprconf

Meu ambiente **Arch Linux + Hyprland**: barra, lançador, seletor de
wallpaper e tema, gerenciador de pacotes e configurações feitos em Quickshell,
com um tema de cores que vale para o sistema todo.

## Instalação

Precisa de Arch Linux com `sudo` e `git`. O `yay` é opcional e só serve para
a aba AUR do app Pacotes.

```bash
git clone https://github.com/luracore/hyprconf ~/hyprconf
~/hyprconf/install.sh
```

O repositório precisa ficar em `~/hyprconf`. O `install.sh` instala as
dependências (pede `sudo`), liga as configurações em `~/.config` e aplica um
tema. Depois, saia e entre de novo no Hyprland.

## Uso

- `SUPER + SPACE` abre o lançador de aplicativos.
- O app **Configurações** (no lançador) leva a tudo que dá para mudar:
  wallpapers, temas, atalhos, programas padrão, pacotes, monitores, aparência
  e o que abre com o Hyprland.
- Para atualizar: `git pull` em `~/hyprconf` e rode o `install.sh` de novo.
  Wallpapers e tema escolhido continuam como estão.
