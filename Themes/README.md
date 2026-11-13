# Temas

Cada `.json` desta pasta é um tema. `current` é um symlink para o tema ativo.

## Trocar

Pelo seletor (`SUPER + T`, `j/k` escolhem o tema) ou pela linha de comando:

```bash
ln -sfn TokyoNight.json ~/hyprconf/Themes/current
~/hyprconf/Themes/converters/main.js
```

O `converters/main.js` aplica no foot, Neovim, GTK, Qt, na tela de bloqueio
(hyprlock) e nos ícones (as pastas do Papirus ganham a cor primária), e avisa a
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

GTK, Qt, apps KDE e ícones são do sistema, então o próprio conversor traz os
arquivos que apontam para o current: a pasta `home/` dele (no caminho a partir
do `$HOME`) e um `dconf.ini` para o gsettings. O `install.sh` copia só o que
ainda não existir e escreve só as chaves do gsettings que ainda estão no padrão.
Se você já tinha esses arquivos, compare com os prontos e ligue à mão.

| Toolkit | current | Arquivos prontos |
| :--- | :--- | :--- |
| GTK | `~/.local/share/themes/Hyprconf/colors.css` | o tema em si, `gtk-3.0/settings.ini`, `gtk-4.0/gtk.css`, gsettings |
| Qt | `~/.config/qt6ct/colors/current.conf` | `qt6ct.conf`, `colors/tokyonight.conf` |
| apps KDE | as cores dentro do `~/.config/kdeglobals` (não dá para apontar) | `kdeglobals` |
| ícones | `~/.local/share/icons/Hyprconf/` | a pasta (herda do Papirus), gsettings |

Apagar a pasta de um conversor tira aquele programa do hyprconf: o tema não é
mais gerado e o install não copia mais os arquivos dele.

O hyprconf só escreve se a pasta já existir: ele não cria config para ninguém.
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
