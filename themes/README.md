# Temas

Cada `.json` desta pasta é um tema. `current` é um symlink para o tema ativo.

## Trocar

Pelo seletor (`SUPER + T`, `j/k` escolhem o tema) ou pela linha de comando:

```bash
ln -sfn TokyoNight.json ~/hyprconf/themes/current
~/hyprconf/themes/converters/main.js
```

O `converters/main.js` aplica no foot, Neovim, OpenCode, GTK, Qt, na tela de
bloqueio (hyprlock), no fzf do RepoStore, nos ícones (as pastas do Papirus ganham a cor primária) e no cursor
(desenhado em SVG no próprio conversor), e avisa a
barra e os outros apps do Quickshell abertos. Só trocar o link não basta: rode
o `main.js` depois.

## Usar o tema em outros programas

Cada programa tem um conversor em [`converters/`](converters/), uma pasta por
programa. Ele escreve o tema no **current** do programa: um arquivo na config
dele, fora do git, que a config usa como tema ativo. A config continua sendo do
programa: ela só precisa usar o current (e pode trazer um tema pronto ao lado,
para quando não houver hyprconf).

| Programa | current | Na config do programa |
| :--- | :--- | :--- |
| foot | `~/.config/foot/current.ini` | `include=~/.config/foot/current.ini` no `foot.ini` |
| Neovim | `~/.config/nvim/colors/current.lua` | `:colorscheme current` |
| OpenCode | a paleta do terminal (a do foot) | `"theme": { "name": "system" }` no `cli.json` |
| Hyprland (cor de fundo) | `~/.config/hypr/config/current.lua` | `require("./config/current")` no `hyprland.lua` |
| hyprlock | `~/.config/hypr/hyprlock-current.conf` | `source = ~/.config/hypr/hyprlock-current.conf` no `hyprlock.conf` |
| fzf (RepoStore) | `apps/repostore/fzf-current.opts` | lido pelo `lib/common.sh` |

As pastas de config desses programas e dos temas de GTK, ícones e cursor ficam
em `hyprconf/defaults/`, e o `install.sh` liga cada uma ao seu lugar (a lista
está em `defaults/links`).

| Programa | current | Link |
| :--- | :--- | :--- |
| GTK3 (tema) | `defaults/gtk/colors.css`, link para o do GTK4 | `~/.local/share/themes/Hyprconf` |
| GTK4/libadwaita | `defaults/gtk-4.0/colors.css` | `~/.config/gtk-4.0` |
| Qt | `defaults/qt6ct/colors/current.conf` | `~/.config/qt6ct` |
| ícones | `defaults/icons/` (herda do Papirus) | `~/.local/share/icons/Hyprconf` |
| cursor | `defaults/cursor/` | `~/.local/share/icons/Hyprconf-Cursor` |

O `kdeglobals` (apps KDE) e o `gtk-3.0/settings.ini` ficam em `defaults/xdg/`,
que o `hypr/config/env.lua` põe no `XDG_CONFIG_DIRS`: os seus em `~/.config`
valem por cima deles. O gsettings (tema GTK, ícones e cursor no Wayland) vem do
`dconf.ini` de cada conversor: o `install.sh` escreve e o `uninstall.sh` volta
ao padrão.

Apagar a pasta de um conversor tira aquele programa do hyprconf: o tema não é
mais gerado.

A pasta de cada current vem dos defaults: sem ela, o conversor falha e avisa,
sem criar config para ninguém.
Os terminais foot abertos trocam de cor na hora; o Neovim recarrega se a config
dele observar o arquivo.

Para ligar um programa novo: crie `converters/<programa>/index.js` com o
`target` (o current dele) e o `generate` (o conteúdo).

## Criar um tema

Crie um `Nome.json` nesta pasta. Ele aparece sozinho no seletor.

```json
{
  "neutrals": {
    "background": "#1A1B26",
    "surface": "#24283B",
    "outline": "#414868",
    "muted": "#565F89",
    "text": "#C0CAF5"
  },

  "palette": {
    "red": "#F7768E",
    "orange": "#FF9E64",
    "yellow": "#E0AF68",
    "green": "#9ECE6A",
    "cyan": "#7DCFFF",
    "blue": "#7AA2F7",
    "magenta": "#BB9AF7"
  },

  "roles": {
    "primary": "blue",
    "secondary": "magenta",
    "tertiary": "cyan",
    "error": "red",
    "warning": "yellow",
    "success": "green",
    "info": "#73DACA"
  }
}
```

- **Obrigatórios:** `neutrals.background`, `neutrals.text` e as seis cores
  `red`, `yellow`, `green`, `cyan`, `blue`, `magenta`. Se faltar alguma, ela
  vem de um tema padrão (com aviso no log).
- **Opcionais:** `surface`, `overlay`, `outline` e `muted` são misturas de
  `background` com `text`; `orange` é a mistura de `red` com `yellow`.
- **Papéis** (`roles`): o nome de uma cor do tema ou um hex. Os que faltarem
  usam o padrão acima. `primary` é a cor de destaque principal (bordas,
  seleção, cursor).
- A cor do texto sobre cada cor de destaque é escolhida sozinha, pelo
  contraste.

As regras ficam no [`Colors.js`](Colors.js).
