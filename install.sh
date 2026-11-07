#!/usr/bin/env bash
#
# install.sh — aplica as configurações do Hyprconf.
#

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

echo "==> Habilitando serviços"

enable_service() {
  local unit="$1"

  if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "$unit"; then
    if ! sudo systemctl enable --now "$unit"; then
      echo "    aviso: falha ao habilitar/iniciar $unit" >&2
    else
      echo "    serviço ativo: $unit"
    fi
  else
    echo "    aviso: serviço $unit não encontrado; ignorado" >&2
  fi
}

enable_service NetworkManager
enable_service bluetooth

if systemctl list-unit-files power-profiles-daemon.service --no-legend 2>/dev/null | grep -q power-profiles-daemon; then
  enable_service power-profiles-daemon
fi

echo "==> Ajustando o perfil de áudio do Bluetooth"

if command -v wpctl >/dev/null 2>&1 && wpctl status >/dev/null 2>&1; then
  wpctl settings --save bluetooth.autoswitch-to-headset-profile false || true
else
  echo "    PipeWire/WirePlumber não está rodando; ajuste ignorado."
fi

echo "==> Recarregando o Hyprland"

if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  hyprctl reload
else
  echo "    Hyprland não está rodando; recarregue manualmente depois."
fi

echo
echo "Hyprconf instalado."
