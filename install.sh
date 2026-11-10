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

  ln -sfn "$source" "$dest"
  echo "    link:   $dest -> $source"
}

link_config hypr
link_config foot

echo "==> Conferindo o tema da barra"

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
echo "Hyprconf instalado."
