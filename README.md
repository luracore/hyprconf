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
├── Thunar/                   # ações do menu de contexto (uca.xml)
├── pacman/                   # makepkg.conf do usuário (sem pacotes -debug)
└── packages/
    └── hyprconf-deps/        # metapacote: a lista de dependências do setup
```

O repositório precisa ficar em `~/hyprconf`: vários caminhos (atalhos,
startup, seletor) apontam para lá.

## Dependências

A lista oficial é o metapacote
[`packages/hyprconf-deps/PKGBUILD`](packages/hyprconf-deps/PKGBUILD): um
pacote vazio que depende de tudo que o setup usa, com um comentário dizendo
para que serve cada um. Todos estão nos repositórios oficiais. O
`install.sh` instala o metapacote (e, com ele, o que faltar); para fazer à
mão:

```bash
cd ~/hyprconf/packages/hyprconf-deps
makepkg -si --clean
```

Os pacotes do setup ficam registrados como **dependência** do metapacote, não
como instalados por você. Quando um deles sai da lista (trocado por outro, por
exemplo) e o metapacote é reinstalado, ele vira órfão e aparece como sobra:

```bash
pacman -Qdt                      # lista o que sobrou
sudo pacman -Rns $(pacman -Qdtq) # remove
```

Os programas que você instala por conta própria continuam como "instalados
por você" e nunca aparecem como sobra.

Opcional: `dart`, para o LSP de Dart no Neovim.

## Instalação

```bash
cd ~
git clone https://github.com/luracore/hyprconf
cd hyprconf
./install.sh
```

O `install.sh`:

1. confere se o repositório está em `~/hyprconf` e instala o metapacote
   `hyprconf-deps` (pede `sudo`); os pacotes do setup que estavam como
   "instalados por você" passam a ser dependência dele;
2. cria os links em `~/.config` (`hypr`, `foot`, `nvim`, `Thunar/uca.xml`,
   `pacman/makepkg.conf`).
   Uma pasta que já existia vira `nome.bak`;
3. define o Thunar como gerenciador de arquivos padrão e adiciona o atalho
   `admin:///etc` no painel lateral;
4. sorteia um tema e um wallpaper, se ainda não houver, e aplica o tema;
5. ativa o NetworkManager, o Bluetooth e o power-profiles-daemon (pede `sudo`);
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
| Rede | ícone do cabo ou do sinal do Wi-Fi; clique abre o painel de rede (ver abaixo) |
| Bluetooth | ícone do estado; clique abre o painel de Bluetooth (ver abaixo) |
| Volume | clique abre o painel de áudio (volume e dispositivo de saída/entrada); clique do meio: mudo; scroll: ±5% |
| Brilho | tela do notebook ou monitor externo (detecta sozinho); scroll: ±5%; teclas de brilho: ±10%; clique relê o valor |
| Sistema | mostra o mais urgente entre bateria, CPU, RAM e temperatura; clique abre o painel Sistema (ver abaixo) |
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

Quando os módulos da direita não cabem até o relógio (tela menor, muitos
ícones na bandeja), eles ficam compactos, só com o ícone, em vez de passar por
cima dele.

### Módulo e painel Sistema

Na barra, o módulo mostra o que for mais urgente, nesta ordem:

1. bateria em 15% ou menos, descarregando;
2. temperatura da CPU em 90 °C ou mais;
3. CPU em 85% ou mais;
4. RAM em 90% ou mais;
5. temperatura da CPU em 80 °C ou mais;
6. sem alertas: a bateria no notebook, a CPU no PC.

Um alerta só sai quando o valor cai um pouco abaixo do limite, para o módulo
não ficar pulando. O painel mostra a bateria (no notebook: carga, tempo até
acabar ou encher, consumo e saúde, quando o notebook informa), CPU, memória,
temperatura da CPU e o perfil de energia (Economia, Equilibrado, Desempenho).
Os perfis vêm do power-profiles-daemon, que não convive com o TLP. A
temperatura é lida direto do kernel (`coretemp` na Intel, `k10temp` na AMD).

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

Temas disponíveis: `EverforestDark`, `GruvboxDark`, `KanagawaWave`, `OsakaJade`,
`Retro82` e `TokyoNight`. Para criar um, veja
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
