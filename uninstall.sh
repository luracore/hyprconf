#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

if [[ $EUID -eq 0 ]]; then
  echo "Rode este script como seu usuário normal (não como root)." >&2
  exit 1
fi

echo "==> Removendo os links para $REPO_DIR"

while IFS= read -r -d '' link; do
  [[ "$(readlink -- "$link")" == "$REPO_DIR"/* ]] || continue
  rm -- "$link"
  echo "    removido: $link"

  shopt -s nullglob
  backups=("$link".bak.*)
  shopt -u nullglob

  if (( ${#backups[@]} > 0 )); then
    backup="$(printf '%s\n' "${backups[@]}" | sort | tail -n 1)"
    mv -- "$backup" "$link"
    echo "    restaurado: $backup -> $link"
  fi
done < <(find "$CONFIG_DIR" "$DATA_DIR" -maxdepth 2 -type l -print0)

echo "==> Voltando o gsettings ao padrão"

for ini in "$REPO_DIR"/themes/converters/*/dconf.ini; do
  section=""
  while IFS= read -r line; do
    case "$line" in
      \[*\])
        section="${line#[}"
        section="${section%]}"
        ;;
      *=*)
        dconf reset "/$section/${line%%=*}" && echo "    ${line%%=*}"
        ;;
    esac
  done < <(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$ini")
done

OVERRIDE="$DATA_DIR/flatpak/overrides/global"

if [[ -f "$OVERRIDE" ]]; then
  echo "==> Tirando o acesso dos apps Flatpak às cores do GTK4"
  sed -i -e 's|xdg-config/gtk-4.0:ro;||' -e '/^filesystems=$/d' "$OVERRIDE"
fi

echo "==> Restaurando o perfil de áudio do Bluetooth"

if wpctl settings --delete bluetooth.autoswitch-to-headset-profile; then
  echo "    troca automática para headset volta ao padrão"
else
  echo "    aviso: não foi possível restaurar (o PipeWire está rodando?)" >&2
fi

echo
echo "Hyprconf desinstalado. Saia do Hyprland para encerrar a sessão atual."
echo "Os outros backups (*.bak.*) continuam onde estavam."
