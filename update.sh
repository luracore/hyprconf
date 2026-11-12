#!/usr/bin/env bash
#
# update.sh — baixa a versão nova do Hyprconf e instala de novo por cima.
# O install.sh pode rodar quantas vezes quiser: atualiza as dependências,
# refaz os links e apaga os restos de versões antigas. Wallpapers e o tema
# escolhido ficam como estão.

# Tudo dentro de chaves: o bash lê o script inteiro antes de rodar, então o
# git pull pode trocar este arquivo sem atrapalhar.
{
  set -euo pipefail

  REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  cd "$REPO_DIR"

  echo "==> Baixando a versão nova"

  if ! git pull --ff-only; then
    echo >&2
    echo "Não deu para atualizar: há mudanças locais que conflitam com as novas," >&2
    echo "ou o histórico divergiu. Veja com 'git status' em $REPO_DIR." >&2
    exit 1
  fi

  echo
  exec "$REPO_DIR/install.sh"
}
