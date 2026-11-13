# Neovim

Configuração do Neovim (lazy.nvim, LSP via Mason, Telescope, treesitter,
blink.cmp). Faz parte do [hyprconf](../README.md): o `install.sh` liga
`~/.config/nvim` a esta pasta.

## Tema

O colorscheme é `colors/current.lua` (fora do git), o tema ativo. O hyprconf
escreve nele o tema do sistema a cada troca de tema. Para usar o tema que vem
pronto, sem o hyprconf:

```bash
ln -sfn tokyonight.lua ~/.config/nvim/colors/current.lua
```

Sem o `current.lua`, o Neovim fica com as cores padrão e avisa.

Quando o `current.lua` muda, as instâncias abertas recarregam sozinhas
(`lua/colorscheme.lua`).

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
