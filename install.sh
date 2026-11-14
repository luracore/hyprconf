#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

if [[ $EUID -eq 0 ]]; then
  echo "Rode este script como seu usuário normal (não como root)." >&2
  exit 1
fi

if [[ "$REPO_DIR" != "$HOME/hyprconf" ]]; then
  echo "aviso: o repositório está em $REPO_DIR, mas precisa ficar em ~/hyprconf" >&2
  echo "       (atalhos, startup e seletor apontam para lá). Mova e rode de novo." >&2
  exit 1
fi

ask() {
  local answer
  read -rp "$1 [S/n] " answer
  [[ ! "$answer" =~ ^[nN] ]]
}

ask "Fazer backup do que for substituído?" && BACKUP=1 || BACKUP=0
ask "Usar os defaults do hyprconf ($(awk '{ printf "%s%s", sep, $1; sep = ", " }' "$REPO_DIR/defaults/links"))?" &&
  DEFAULTS=1 || DEFAULTS=0

PREPARED_PATHS=()

prepare_destination() {
  local dest="$1"
  local path backup

  for path in "${PREPARED_PATHS[@]}"; do
    [[ "$path" == "$dest" ]] && return 0
  done
  PREPARED_PATHS+=("$dest")

  [[ -e "$dest" || -L "$dest" ]] || return 0
  [[ -L "$dest" && "$(readlink -- "$dest")" == "$REPO_DIR"/* ]] && return 0

  if (( BACKUP )); then
    backup="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$dest" "$backup"
    echo "    backup: $dest -> $backup"
  else
    rm -rf -- "$dest"
    echo "    removido: $dest"
  fi
}

link() {
  local source="$REPO_DIR/$1"
  local dest="$2"

  if [[ ! -e "$source" ]]; then
    echo "    aviso: $source não existe; link ignorado" >&2
    return
  fi

  mkdir -p "$(dirname -- "$dest")"
  prepare_destination "$dest"
  ln -sfnT "$source" "$dest"
  echo "    link:   $dest -> $source"
}

echo "==> Criando links simbólicos"

link hypr "$CONFIG_DIR/hypr"

if (( DEFAULTS )); then
  while read -r name dest; do
    [[ -n "$name" ]] && link "defaults/$name" "$HOME/$dest"
  done < "$REPO_DIR/defaults/links"
fi

echo "==> Criando atalhos dos aplicativos"

mkdir -p "$DATA_DIR/applications"

shopt -s nullglob
desktops=("$REPO_DIR"/applications/*.desktop)
shopt -u nullglob

for desktop in "${desktops[@]}"; do
  link="$DATA_DIR/applications/$(basename -- "$desktop")"
  prepare_destination "$link"
  ln -sfnT "$desktop" "$link"
  echo "    link:   $link -> $desktop"
done

echo "==> Aplicando as prioridades iniciais do lançador"

LAUNCHER_STATE="$REPO_DIR/apps/quicklauncher/state"
LAUNCHER_DEFAULTS="$LAUNCHER_STATE/defaults.json"
LAUNCHER_PINS="$LAUNCHER_STATE/pins.json"

mkdir -p "$LAUNCHER_STATE"

if [[ ! -e "$LAUNCHER_PINS" && -f "$LAUNCHER_DEFAULTS" ]]; then
  cp -- "$LAUNCHER_DEFAULTS" "$LAUNCHER_PINS"
  echo "    criado: $LAUNCHER_PINS"
fi

if (( DEFAULTS )); then
  echo "==> Apontando GTK, ícones e cursor para o tema (gsettings)"

  for ini in "$REPO_DIR"/themes/converters/*/dconf.ini; do
    section=""
    while IFS= read -r line; do
      case "$line" in
        \[*\])
          section="${line#[}"
          section="${section%]}"
          ;;
        *=*)
          dconf write "/$section/${line%%=*}" "${line#*=}" &&
            echo "    ${line%%=*} = ${line#*=}"
          ;;
      esac
    done < <(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$ini")
  done

  if command -v flatpak >/dev/null; then
    flatpak override --user --filesystem=xdg-config/gtk-4.0:ro &&
      echo "    apps Flatpak: acesso às cores do GTK4"
  fi
fi

echo "==> Conferindo o tema e o wallpaper"

THEME_LINK="$REPO_DIR/themes/current"

if [[ -e "$THEME_LINK" ]]; then
  echo "    tema atual: $(basename -- "$(readlink -f -- "$THEME_LINK")")"
else
  themes=("$REPO_DIR"/themes/*.json)

  if [[ -e "${themes[0]:-}" ]]; then
    theme="$(basename -- "${themes[RANDOM % ${#themes[@]}]}")"
    ln -sfn "$theme" "$THEME_LINK"
    echo "    tema sorteado: $theme"
  else
    echo "    aviso: nenhum tema em $REPO_DIR/themes; a barra usará o tema padrão" >&2
  fi
fi

WALLPAPER_LINK="$REPO_DIR/wallpapers/current"

if [[ -e "$WALLPAPER_LINK" ]]; then
  echo "    wallpaper atual: $(basename -- "$(readlink -f -- "$WALLPAPER_LINK")")"
else
  shopt -s nullglob nocaseglob
  wallpapers=("$REPO_DIR"/wallpapers/*.{jpg,jpeg,png,webp})
  shopt -u nullglob nocaseglob

  if (( ${#wallpapers[@]} > 0 )); then
    wallpaper="${wallpapers[RANDOM % ${#wallpapers[@]}]}"
    ln -sfn "$wallpaper" "$WALLPAPER_LINK"
    echo "    wallpaper sorteado: $(basename -- "$wallpaper")"
  else
    echo "    aviso: nenhuma imagem em $REPO_DIR/wallpapers; o fundo ficará preto" >&2
  fi
fi

echo "==> Aplicando o tema"

if [[ -e "$THEME_LINK" ]]; then
  # Faz backup dos destinos externos antes de os conversores escreverem neles.
  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    [[ "$(realpath -m -- "$target")" == "$REPO_DIR"/* ]] && continue
    prepare_destination "$target"
  done < <(node -e '
    const fs = require("fs");
    const path = require("path");
    const dir = process.argv[1];

    for (const name of fs.readdirSync(dir)) {
      const file = path.join(dir, name, "index.js");
      if (fs.existsSync(file)) {
        const converter = require(file);
        if (converter.target) console.log(converter.target);
      }
    }
  ' "$REPO_DIR/themes/converters")

  node "$REPO_DIR/themes/converters/main.js" ||
    echo "    aviso: não foi possível aplicar o tema (veja as mensagens acima)" >&2
fi

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
echo "  - saia e entre de novo no Hyprland: a barra, o lançador e as variáveis de"
echo "    ambiente (como a do qt6ct) só pegam tudo o que foi instalado numa sessão nova;"
echo "  - abra o nvim uma vez: ele baixa os plugins e o Mason instala os LSPs;"
echo "  - SUPER + SPACE abre o lançador; o HyprSettings leva a todo o resto."

