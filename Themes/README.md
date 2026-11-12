# Temas

Cada `.json` desta pasta é um tema. `current` é um symlink para o tema ativo.

## Trocar

Pelo seletor (`SUPER + M`, `j/k` escolhem o tema) ou pela linha de comando:

```bash
ln -sfn TokyoNight.json ~/hyprconf/Themes/current
~/hyprconf/Themes/apply-theme.js
```

A barra percebe a troca sozinha; o `apply-theme.js` aplica no foot, Neovim,
GTK, Qt, na tela de bloqueio (hyprlock) e nos ícones (as pastas do Papirus
ganham a cor primária).

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

As regras ficam no [`ThemeColors.js`](ThemeColors.js).
