#!/usr/bin/env bash
#
# install.sh — aplica as configurações do Hyprconf.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ $EUID -eq 0 ]]; then
  echo "Rode este script como seu usuário normal (não como root)." >&2
  exit 1
fi

if [[ "$REPO_DIR" != "$HOME/hyprconf" ]]; then
  echo "aviso: o repositório está em $REPO_DIR, mas precisa ficar em ~/hyprconf" >&2
  echo "       (atalhos, startup e seletor apontam para lá). Mova e rode de novo." >&2
  exit 1
fi

echo "==> Conferindo as dependências"

# comando -> pacote (só avisa; a lista completa está no README)
declare -A DEPS=(
  [hyprctl]=hyprland [hyprlock]=hyprlock [hypridle]=hypridle
  [quickshell]=quickshell [awww]=awww [magick]=imagemagick [jq]=jq
  [node]=nodejs [foot]=foot [nvim]=neovim [thunar]=thunar
  [qt6ct]=qt6ct [cava]=cava [ddcutil]=ddcutil [playerctl]=playerctl
  [wpctl]=wireplumber [xdg-mime]=xdg-utils [gsettings]=glib2
  [nmcli]=networkmanager [nm-applet]=network-manager-applet
  [nm-connection-editor]=nm-connection-editor
  [bluetoothctl]=bluez-utils [pactl]=libpulse
)

missing=()
for cmd in "${!DEPS[@]}"; do
  command -v "$cmd" >/dev/null || missing+=("${DEPS[$cmd]}")
done

if [[ ! -d /usr/share/themes/adw-gtk3-dark ]]; then
  missing+=(adw-gtk-theme)
fi

if ! fc-list 2>/dev/null | grep -qi "FiraCode Nerd Font"; then
  missing+=(ttf-firacode-nerd)
fi

if (( ${#missing[@]} > 0 )); then
  echo "    aviso: faltam pacotes: ${missing[*]}" >&2
  echo "    instale com: sudo pacman -S --needed ${missing[*]}" >&2
  echo "    (o resto da instalação continua, mas essas partes não vão funcionar)" >&2
else
  echo "    tudo instalado"
fi

echo "==> Criando links simbólicos em $CONFIG_DIR"

mkdir -p "$CONFIG_DIR"

link_config() {
  local name="$1"
  local source="$REPO_DIR/$name"
  local dest="$CONFIG_DIR/$name"

  if [[ ! -e "$source" ]]; then
    echo "    aviso: $source não existe; link ignorado" >&2
    return
  fi

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    local backup="$dest.bak"

    if [[ -e "$backup" || -L "$backup" ]]; then
      backup="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    fi

    mv "$dest" "$backup"
    echo "    backup: $dest -> $backup"
  fi

  mkdir -p "$(dirname -- "$dest")"
  ln -sfn "$source" "$dest"
  echo "    link:   $dest -> $source"
}

link_config hypr
link_config foot
link_config nvim
link_config Thunar/uca.xml

echo "==> Configurando o Thunar"

# Thunar como gerenciador de arquivos padrão
if xdg-mime default thunar.desktop inode/directory; then
  echo "    padrão para pastas: thunar.desktop"
else
  echo "    aviso: não foi possível definir o Thunar como padrão (xdg-utils instalado?)" >&2
fi

# Atalho para /etc com permissão de root (gvfs admin://) no painel lateral
BOOKMARKS="$CONFIG_DIR/gtk-3.0/bookmarks"
mkdir -p "$(dirname -- "$BOOKMARKS")"
if ! grep -qs '^admin:///etc ' "$BOOKMARKS"; then
  echo 'admin:///etc /etc (root)' >> "$BOOKMARKS"
  echo "    atalho adicionado: admin:///etc"
fi

echo "==> Conferindo o tema e o wallpaper"

THEME_LINK="$REPO_DIR/Themes/current"

if [[ -e "$THEME_LINK" ]]; then
  echo "    tema atual: $(basename -- "$(readlink -f -- "$THEME_LINK")")"
else
  themes=("$REPO_DIR"/Themes/*.json)

  if [[ -e "${themes[0]}" ]]; then
    theme="$(basename -- "${themes[RANDOM % ${#themes[@]}]}")"
    ln -sfn "$theme" "$THEME_LINK"
    echo "    tema sorteado: $theme"
  else
    echo "    aviso: nenhum tema em $REPO_DIR/Themes; a barra usará o tema padrão" >&2
  fi
fi

WALLPAPER_LINK="$REPO_DIR/Wallpapers/current"

if [[ -e "$WALLPAPER_LINK" ]]; then
  echo "    wallpaper atual: $(basename -- "$(readlink -f -- "$WALLPAPER_LINK")")"
else
  shopt -s nullglob nocaseglob
  wallpapers=("$REPO_DIR"/Wallpapers/*.{jpg,jpeg,png,webp})
  shopt -u nullglob nocaseglob

  if (( ${#wallpapers[@]} > 0 )); then
    wallpaper="${wallpapers[RANDOM % ${#wallpapers[@]}]}"
    ln -sfn "$wallpaper" "$WALLPAPER_LINK"
    echo "    wallpaper sorteado: $(basename -- "$wallpaper")"
  else
    echo "    aviso: nenhuma imagem em $REPO_DIR/Wallpapers; o fundo ficará preto" >&2
  fi
fi

echo "==> Aplicando o tema no foot, Neovim, GTK e Qt"

if [[ -e "$THEME_LINK" ]]; then
  node "$REPO_DIR/Themes/apply-theme.js" ||
    echo "    aviso: não foi possível aplicar o tema (veja as mensagens acima)" >&2
fi

echo "==> Habilitando serviços"

# Tenta ativar a unit; se falhar (pacote não instalado, por exemplo),
# só avisa e segue para o próximo passo.
enable_service() {
  local unit="$1"

  if sudo systemctl enable --now "$unit"; then
    echo "    serviço ativo: $unit"
  else
    echo "    aviso: não foi possível ativar $unit (o pacote está instalado?)" >&2
  fi
}

enable_service NetworkManager.service
enable_service bluetooth.service

echo "==> Ajustando o perfil de áudio do Bluetooth"

if wpctl settings --save bluetooth.autoswitch-to-headset-profile false; then
  echo "    troca automática para headset desativada"
else
  echo "    aviso: não foi possível ajustar (o PipeWire está rodando?)" >&2
fi

echo "==> Recarregando o Hyprland"

if hyprctl reload; then
  echo "    Hyprland recarregado"
else
  echo "    aviso: não foi possível recarregar; recarregue manualmente depois." >&2
fi

echo
echo "Hyprconf instalado. Próximos passos:"
echo "  - saia e entre de novo no Hyprland (variáveis de ambiente, como a do qt6ct);"
echo "  - abra o nvim uma vez: ele baixa os plugins e o Mason instala os LSPs;"
echo "  - SUPER + M abre o seletor de wallpaper e tema."
