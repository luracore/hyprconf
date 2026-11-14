#!/usr/bin/env bash
# Abre o seletor de wallpaper/tema, ou fecha se já estiver aberto
# (SUPER + T e HyprSettings).
set -uo pipefail

path="$HOME/hyprconf/apps/quickstyle/shell.qml"

# o seletor só existe enquanto está na tela: se o IPC responde, ele fecha
if quickshell ipc --path "$path" call style toggle >/dev/null 2>&1; then
  exit 0
fi

# -n: não abre um segundo se o atalho for apertado durante a abertura
exec quickshell -n --path "$path"
