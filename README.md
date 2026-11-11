# Hyprconf

Configurações pessoais do meu ambiente **Arch Linux + Hyprland (Wayland)**.

- Barra (com tela de energia e painéis de áudio, rede e Bluetooth), lançador
  de aplicativos e seletor de wallpaper/tema feitos em **Quickshell**.
- Um tema de cores que vale para o sistema todo: barra, foot, Neovim, GTK e Qt.
- Configurações do Hyprland, do Neovim e do Thunar.

## Sumário

- [Estrutura](#estrutura)
- [Dependências](#dependências)
- [Instalação](#instalação)
- [Atalhos](#atalhos)
- [Barra](#barra)
- [Lançador](#lançador-super--space)
- [Temas](#temas)
- [Wallpapers](#wallpapers)
- [Thunar](#thunar)

## Estrutura

```text
hyprconf/
├── install.sh                # confere dependências, cria os links, aplica o tema
├── hypr/
│   ├── hyprland.lua          # carrega config/*.lua
│   ├── hypridle.conf
│   ├── hyprlock.conf
│   └── config/
│       ├── env.lua           # variáveis de ambiente (qt6ct)
│       ├── startup.lua       # wallpaper, barra, hypridle…
│       ├── binds.lua         # atalhos (ver tabela abaixo)
│       ├── window-rules.lua  # regras de janela e de camada (blur)
│       └── animations.lua, appearance.lua, input.lua, layout.lua, monitor.lua
├── quickshell/
│   ├── bar/                  # barra + tela de energia + painéis (ver bar/README.md)
│   ├── launcher/             # lançador de aplicativos (SUPER + SPACE)
│   ├── wallpaper-picker/     # seletor de wallpaper e tema (SUPER + M)
│   └── common/               # tema, tipografia e medidas usados pela barra e pelo lançador
├── Themes/                   # temas (*.json) + current, ThemeColors.js, apply-theme.js
├── Wallpapers/               # imagens + current (symlink) + thumbnails/ (gerado)
├── foot/                     # foot.ini (cores vêm do tema)
├── nvim/                     # config do Neovim (colorscheme segue o tema)
└── Thunar/                   # ações do menu de contexto (uca.xml)
```

O repositório precisa ficar em `~/hyprconf`: vários caminhos (atalhos,
startup, seletor) apontam para lá.

## Dependências

O `install.sh` **não** instala pacotes (ele só avisa o que falta). Instale as
dependências antes, com o sistema atualizado (as configs assumem a versão mais
recente de cada pacote). Todos estão nos repositórios oficiais:

```bash
sudo pacman -Syu --needed \
  hyprland hyprlock hypridle hyprshot hyprpolkitagent \
  xdg-desktop-portal-hyprland xdg-utils \
  quickshell awww imagemagick cava curl jq nodejs \
  foot thunar gvfs tumbler thunar-archive-plugin file-roller \
  qt6ct adw-gtk-theme breeze-icons ttf-firacode-nerd \
  neovim npm ripgrep tree-sitter-cli gcc unzip clang \
  pipewire-pulse wireplumber playerctl \
  networkmanager network-manager-applet nm-connection-editor \
  bluez bluez-utils libpulse \
  ddcutil \
  opencode \
  git
```

Para que servem as menos óbvias:

| Pacote | Usado por |
| --- | --- |
| `awww` | daemon de wallpaper |
| `imagemagick` | miniaturas do seletor de wallpaper |
| `jq` | lista de temas do seletor (`themes.sh`) |
| `nodejs` | `Themes/apply-theme.js` e servidores de linguagem do Neovim |
| `cava` | visualizador de áudio na barra |
| `qt6ct`, `adw-gtk-theme`, `breeze-icons` | tema nos apps Qt e GTK |
| `ttf-firacode-nerd` | fonte (com ícones) da barra, do foot e do Neovim |
| `gvfs`, `tumbler` | lixeira, pendrives, `admin://` e miniaturas no Thunar |
| `nm-connection-editor` | botão "Avançado" do painel de rede (VPN, casos raros) |
| `network-manager-applet` | agente de senhas do NetworkManager (roda escondido; o ícone fica fora da bandeja) |
| `bluez-utils` | `bluetoothctl`, usado como agente de pareamento do Bluetooth |
| `libpulse` | `pactl`, para trocar o perfil/codec do áudio Bluetooth |
| `ddcutil` | brilho do monitor externo (DDC/CI) |
| `npm`, `unzip` | Mason (instala os LSPs do Neovim) |
| `ripgrep` | busca em arquivos do Telescope (`<leader>fg`) |
| `tree-sitter-cli`, `gcc` | compilar os parsers do nvim-treesitter |
| `clang` | `clangd` (LSP de C/C++) |

Opcional: `dart` para o LSP de Dart.

## Instalação

```bash
cd ~
git clone https://github.com/luracore/hyprconf
cd hyprconf
./install.sh
```

O `install.sh`:

1. confere se o repositório está em `~/hyprconf` e avisa se falta algum
   pacote (inclusive a fonte);
2. cria os links em `~/.config` (`hypr`, `foot`, `nvim`, `Thunar/uca.xml`).
   Uma pasta que já existia vira `nome.bak`;
3. define o Thunar como gerenciador de arquivos padrão e adiciona o atalho
   `admin:///etc` no painel lateral;
4. sorteia um tema e um wallpaper, se ainda não houver, e aplica o tema;
5. ativa o NetworkManager e o Bluetooth (pede `sudo`);
6. desliga a troca automática do fone Bluetooth para o modo headset (que
   derruba a qualidade do som); para usar o microfone do fone, escolha o
   modo "Microfone" no painel de Bluetooth;
7. recarrega o Hyprland.

Depois:

- saia e entre de novo no Hyprland (para valerem as variáveis de ambiente);
- abra o `nvim` uma vez: o lazy.nvim baixa os plugins e o Mason instala os LSPs.

## Atalhos

| Atalho | Ação |
| --- | --- |
| `SUPER + RETURN` | terminal (foot) |
| `SUPER + SPACE` | lançador de aplicativos |
| `SUPER + E` | gerenciador de arquivos (Thunar) |
| `SUPER + M` | seletor de wallpaper e tema |
| `SUPER + A` | opencode no terminal |
| `SUPER + P` | bloquear a tela (hyprlock) |
| `SUPER + SHIFT + P` | tela de energia (bloquear, suspender, sair, reiniciar, desligar) |
| `SUPER + SHIFT + Q` | sair do Hyprland |
| `SUPER + S` / `SUPER + SHIFT + S` | captura de janela / de região |
| `SUPER + H/J/K/L` | mover o foco |
| `SUPER + SHIFT + H/J/K/L` | mover a janela |
| `SUPER + W` | fechar a janela |
| `SUPER + D` | alternar a divisão |
| `SUPER + F` / `SUPER + SHIFT + F` | maximizar / tela cheia |
| `SUPER + 1…0` / `SUPER + SHIFT + 1…0` | ir para / mover para o workspace |
| teclas de mídia | volume e microfone (`wpctl`), player (`playerctl`) e brilho (pela barra) |

## Barra

| Módulo | Interação |
| --- | --- |
| Ícone da distro | clique abre a tela de energia |
| Workspaces | clique troca de workspace |
| Visualizador | barras do áudio tocando (cava), na cor da capa do que está tocando |
| Relógio | clique abre o calendário |
| Bandeja | esquerdo: abre o app; direito: menu; meio: ação secundária |
| Rede | clique abre o painel de rede (ver abaixo) |
| Bluetooth | clique abre o painel de Bluetooth (ver abaixo) |
| Volume | clique abre o painel de áudio (volume e dispositivo de saída/entrada); clique do meio: mudo; scroll: ±5% |
| Brilho | scroll: ±5%; clique relê o valor do monitor; teclas de brilho: ±10% |
| RAM / CPU | uso atual |
| Notificações | clique abre a central (não perturbe, limpar) |

### Painel de rede

- **Cabo:** status e conectar/desconectar.
- **Wi-Fi:** lista as redes; rede aberta conecta com um clique, rede com senha
  abre o campo de senha. Rede salva: conectar, trocar senha, esquecer.
- **Rede corporativa / de faculdade (802.1X, ex. eduroam):** usuário, senha,
  método (PEAP/TTLS) e autenticação interna; em "Mais opções", identidade
  anônima, certificado da CA e domínio do servidor.
- **Rede oculta:** "Conectar a uma rede oculta…".
- Se a senha de uma rede salva deixar de funcionar, o formulário reabre com o
  erro. Rede que pede login no navegador (hotel, aeroporto) mostra um botão
  "Abrir login".
- Engrenagem: abre o `nm-connection-editor` para o resto (VPN, IP fixo…).

Tudo é feito pelo `nmcli`. Este PC não tem Wi-Fi, então a parte de Wi-Fi foi
testada só com dados simulados.

### Painel de Bluetooth

- Liga/desliga o Bluetooth; ao abrir o painel, procura dispositivos por perto
  (e para ao fechar).
- **Dispositivos pareados:** conectar, desconectar, esquecer e bateria. Em
  fones, escolha a qualidade do áudio (codec: LDAC, AAC, SBC…) ou o modo
  "Microfone" (qualidade de ligação, com microfone).
- **Por perto:** clique para parear. Se o dispositivo pedir confirmação de
  código ou PIN, o pedido aparece no painel (ele abre sozinho). Depois de
  pareado, o dispositivo fica como confiável e conecta.

O agente de pareamento é um `bluetoothctl --agent` rodando pela barra; o
perfil do áudio é trocado com `pactl`.

### Tela de energia (`SUPER + SHIFT + P`)

`h/l` ou setas escolhem, `Enter` executa, `Esc` fecha. Sair, reiniciar e
desligar pedem confirmação (`Enter` de novo).

Tudo da barra também pode ser controlado por IPC (lista completa e detalhes
de como ela é organizada em [`quickshell/bar/README.md`](quickshell/bar/README.md)):

```bash
quickshell ipc --path ~/hyprconf/quickshell/bar call power toggle
```

## Lançador (`SUPER + SPACE`)

- Busca pelo nome, descrição e palavras-chave; ignora acentos e aceita letras
  soltas ("ffx" encontra o Firefox).
- `↑/↓`, `Tab` ou `Ctrl + J/K` navegam; `Enter` abre; `Esc` fecha.
- **Números:** botão direito num app atribui um número de 0 a 9. Com a busca
  vazia, os apps com número aparecem primeiro, em ordem; depois, os mais
  abertos.

Fica em `quickshell/launcher/`, numa instância própria do Quickshell iniciada
no login (independente da barra), e abre por IPC:

```bash
quickshell ipc --path ~/hyprconf/quickshell/launcher call launcher toggle
```

## Temas

O tema ativo é `Themes/current`, um symlink para um dos `.json` da pasta. O
jeito mais fácil de trocar é pelo seletor (`SUPER + M`): `h/l` escolhem o
wallpaper, `j/k` o tema, `Enter` aplica os dois (`w` só o wallpaper, `t` só o
tema). Pela linha de comando:

```bash
ln -sfn TokyoNight.json ~/hyprconf/Themes/current
~/hyprconf/Themes/apply-theme.js
```

Temas disponíveis: `OsakaJade`, `Retro82`, `TokyoNight`. Para criar um, veja
[`Themes/README.md`](Themes/README.md).

### Onde o tema é aplicado

| Programa | Como | Quando muda |
| --- | --- | --- |
| Barra e seletor (Quickshell) | leem `Themes/current` direto | na hora |
| foot | `foot.ini` inclui `~/.local/state/hyprconf/theme/foot.ini` | na hora (terminais abertos recebem as cores novas) |
| Neovim | colorscheme `hyprconf` (mini.base16) lê `~/.local/state/hyprconf/theme/nvim.lua` | na hora |
| GTK 3 (Thunar…) | tema `Hyprconf` em `~/.local/share/themes`, baseado no adw-gtk3 | na hora |
| GTK 4 / libadwaita | `~/.config/gtk-4.0/gtk.css` | ao reabrir o app |
| Qt | qt6ct (`QT_QPA_PLATFORMTHEME=qt6ct`, em `hypr/config/env.lua`) + cores KDE em `~/.config/kdeglobals` | ao reabrir o app |

Tudo isso é gerado pelo `Themes/apply-theme.js` a partir do JSON; não edite os
arquivos gerados. A variável do qt6ct só vale para apps abertos depois de um
novo login no Hyprland.

As regras de cor (o que fazer quando o tema não define `surface`, `muted`,
`orange`…) ficam no `Themes/ThemeColors.js`, usado tanto pelo `apply-theme.js`
quanto pela barra e pelo seletor. Os dois acessam o arquivo por symlink,
porque o Quickshell só importa arquivos de dentro da própria pasta.

## Wallpapers

Coloque as imagens (`jpg`, `png`, `webp`) em `Wallpapers/`; o seletor gera as
miniaturas sozinho em `Wallpapers/thumbnails/`. O `.gitignore` ignora tudo
nessa pasta, menos os wallpapers de exemplo.

## Thunar

- **Abrir terminal aqui** (menu de contexto): abre o foot na pasta, inclusive
  em pastas abertas como root.
- **Pastas do sistema como root**: `admin:///caminho` na barra de endereço
  (`Ctrl + L`) pede a senha via polkit (gvfs). O painel lateral já tem um
  atalho para `admin:///etc`.
