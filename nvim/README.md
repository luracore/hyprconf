# Neovim

Configuração do Neovim (lazy.nvim, LSP via Mason, Telescope, treesitter,
blink.cmp), com o colorscheme seguindo o tema do hyprconf.

## Instalação

Esta configuração faz parte do [hyprconf](../README.md): o `install.sh` cria o
link `~/.config/nvim -> ~/hyprconf/nvim`.

## Tema

O colorscheme `hyprconf` (`colors/hyprconf.lua`) segue o tema escolhido em
`~/hyprconf/Themes/current`. A paleta é gerada pelo `Themes/apply-theme.js` em
`~/.local/state/hyprconf/theme/nvim.lua` e aplicada com o
[mini.base16](https://github.com/echasnovski/mini.base16). Instâncias abertas
recarregam sozinhas quando o tema muda.

---

## Keymaps

### Janelas (Splits) e Abas (Tabs)

| Atalho | Modo | Ação |
| :--- | :---: | :--- |
| `<leader>s` | Normal | Cria um novo split vertical |
| `Ctrl + h` / `j` / `k` / `l` | Normal | Move o cursor entre os splits (Esquerda, Baixo, Cima, Direita) |
| `<leader><Tab>` | Normal | Cria uma nova aba |
| `Tab` | Normal | Vai para a próxima aba |
| `Shift + Tab` | Normal | Volta para a aba anterior |

### Terminal e Formatação

| Atalho | Modo | Ação |
| :--- | :---: | :--- |
| `<leader>t` | Normal | Abre o terminal nativo |
| `Esc` | Terminal | Sai do modo de inserção do terminal (volta para o modo Normal) |
| `<leader>=` | Normal | Formata o arquivo atual (usa LSP ou recuo nativo) |

---
