# Barra (Quickshell)

A barra é uma instância do Quickshell iniciada pelo `hypr/config/startup.lua`:

```bash
quickshell --path ~/hyprconf/quickshell/bar
```

Além da barra, a mesma instância cuida da tela de energia, das notificações e
dos painéis (áudio, rede, Bluetooth, calendário). O lançador de aplicativos
fica à parte, em `quickshell/launcher/`, porque não depende da barra.

## Organização

```text
bar/
├── shell.qml                 # só carrega o Bar
├── cava.conf                 # config do cava (visualizador)
├── config -> ../common       # Theme.qml (singleton "Theme"), ThemeColors.js,
│                             # Sizes.js, Typo.js; compartilhado com o lançador
└── modules/
    ├── Bar.qml               # a janela da barra: monta os módulos
    ├── BarButton.qml         # botão padrão dos módulos ([ícone][valor])
    │
    ├── DistroButton.qml      # ícone da distro -> PowerMenu
    ├── Workspaces.qml, Cava.qml, Clock.qml (+ Calendar.qml)
    ├── Tray.qml (+ TrayMenu.qml)
    ├── Network.qml (+ NetworkPanel.qml)
    ├── Bluetooth.qml (+ BluetoothPanel.qml)
    ├── Volume.qml (+ AudioPanel.qml)
    ├── System.qml (+ SystemPanel.qml)     # CPU, RAM, temperatura, bateria, perfil
    ├── Brightness.qml        # backlight (brightnessctl) ou DDC/CI (ddcutil)
    ├── Notifications.qml
    │
    ├── PowerMenu.qml         # tela de energia (tela cheia, SUPER + SHIFT + P)
    │
    ├── Panel*.qml            # peças dos painéis: PanelButton, PanelField,
    │                         # PanelChips, PanelSwitch, PanelIconButton,
    │                         # PanelTitle, PanelError
    └── CommandRunner.qml     # roda comandos e devolve código/stdout/stderr
```

## Padrões

**Módulo com painel** (Volume, Network, Bluetooth, System, Clock): o módulo é um
`BarButton` que guarda o estado e as ações; o painel (`*Panel.qml`) só
desenha, recebendo o módulo numa propriedade (`net`, `bt`). O painel abre num
`PopupWindow` ancorado no botão, e um `HyprlandFocusGrab` fecha ao clicar
fora (com um `Timer` que tenta de novo, porque o grab às vezes falha na
primeira tentativa).

**Modo compacto:** o `Bar.qml` mede o espaço da direita até o relógio; se os
módulos não couberem, liga `compact` nos `BarButton`, que escondem o texto e
ficam só com o ícone.

**Comandos externos:** `CommandRunner.run(args, callback)` roda com
`LC_ALL=C`, para a saída não depender do idioma do sistema.

**Tela cheia** (PowerMenu, e o lançador na instância dele): `PanelWindow` em
camada `Overlay`, com foco de teclado exclusivo enquanto aberta. O blur atrás
vem de uma `layer_rule` em `hypr/config/window-rules.lua` (namespaces
`qs-power` e `qs-launcher`).

**Estado salvo:** fica em `~/.local/state/hyprconf/`, nunca no repositório.

## IPC

Tudo pode ser controlado de fora:

```bash
quickshell ipc --path ~/hyprconf/quickshell/bar show            # lista tudo
quickshell ipc --path ~/hyprconf/quickshell/bar call <alvo> <função> [args]
```

| Alvo | Funções |
| --- | --- |
| `power` | `toggle`, `open`, `close` |
| `network` | `togglePanel`, `rescan` |
| `bluetooth` | `togglePanel` |
| `volume` | `togglePanel`, `up`, `down`, `mute`, `set <0-100>` |
| `brightness` | `up`, `down`, `set <0-100>` |
| `system` | `togglePanel` |
| `notifications` | `toggle`, `open`, `close`, `clear`, `toggleDnd` |
| `bar` | `toggleCalendar`, `nextMonth`, `previousMonth`, `selectOffset <dias>` |
| `theme` | `reloadTheme` |

Não use `show` nem `hide` como nome de função de IPC: `show` é um
subcomando do próprio `quickshell ipc`, e a chamada não chega na função.

## Cuidados

- **Recarregamento automático:** o Quickshell recarrega a barra quando um
  arquivo dela muda. Às vezes ele trava ao destruir os `Shortcut` dos
  painéis antigos (defeito do Qt/Quickshell) e reabre sozinho. Depois de
  mexer em vários arquivos, o mais limpo é reiniciar a barra:

  ```bash
  quickshell kill --path ~/hyprconf/quickshell/bar
  hyprctl dispatch 'hl.dsp.exec_cmd("quickshell --path $HOME/hyprconf/quickshell/bar")'
  ```

- **Imports:** o Quickshell só importa arquivos de dentro da pasta da
  instância; o que é compartilhado entra por symlink (`config -> ../common`,
  e dentro dele `ThemeColors.js -> Themes/ThemeColors.js`).
- **Nomes de propriedade:** nada que comece com `on` + maiúscula (ex.:
  `onPrimary`): o QML trata como handler de sinal.
- **Componentes inline** (`component X: ...`) não enxergam os `id` do arquivo
  de fora; passe o que precisarem por propriedade.
