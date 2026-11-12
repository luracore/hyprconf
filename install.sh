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

echo "==> Instalando as dependências (metapacote hyprconf-deps)"

# O metapacote depende de tudo que o setup usa (packages/hyprconf-deps/PKGBUILD).
# O makepkg instala o que falta (como dependência) e depois o metapacote.
DEPS_DIR="$REPO_DIR/packages/hyprconf-deps"

if ! pacman -Qq base-devel >/dev/null 2>&1; then
  echo "    o makepkg precisa do base-devel"
  sudo pacman -S --needed base-devel
fi

(cd "$DEPS_DIR" && makepkg -si --clean) &&
  rm -f "$DEPS_DIR"/*.pkg.tar.*

# Pacotes do setup que estavam instalados como "explícitos" passam a ser
# dependências do metapacote: se um dia saírem da lista, viram órfãos e
# aparecem como sobra (pacman -Qdt), em vez de ficarem esquecidos.
mapfile -t deps < <(cd "$DEPS_DIR" && bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"')
mapfile -t explicit < <(pacman -Qqe "${deps[@]}" 2>/dev/null)

if (( ${#explicit[@]} > 0 )); then
  echo "    marcando ${#explicit[@]} pacote(s) do setup como dependência do metapacote"
  sudo pacman -D --asdeps "${explicit[@]}" >/dev/null
fi

echo "==> Criando links simbólicos em $CONFIG_DIR"

mkdir -p "$CONFIG_DIR"

# Todo link criado entra nesta lista; no fim, os links para o repositório que
# não estão nela são restos de versões antigas e são apagados.
CREATED_LINKS=()

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
  CREATED_LINKS+=("$dest")
  echo "    link:   $dest -> $source"
}

link_config hypr
link_config foot
link_config nvim
link_config Thunar/uca.xml
link_config pacman/makepkg.conf

# atalhos dos apps do hyprconf (aparecem no lançador)
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$DATA_DIR/applications"
for desktop in "$REPO_DIR"/applications/*.desktop; do
  ln -sfn "$desktop" "$DATA_DIR/applications/$(basename -- "$desktop")"
  CREATED_LINKS+=("$DATA_DIR/applications/$(basename -- "$desktop")")
  echo "    link:   $DATA_DIR/applications/$(basename -- "$desktop")"
done

echo "==> Limpando restos de versões antigas"

# Links para dentro do repositório que esta versão não criou: configs que
# saíram do setup ou arquivos renomeados (eles ficariam quebrados).
removed=0
while IFS= read -r -d '' link; do
  target="$(readlink -- "$link")"
  [[ "$target" == "$REPO_DIR"/* ]] || continue
  for created in "${CREATED_LINKS[@]}"; do
    [[ "$link" == "$created" ]] && continue 2
  done
  rm -f -- "$link"
  echo "    removido: $link -> $target"
  removed=$((removed + 1))
done < <(find "$CONFIG_DIR" "$DATA_DIR/applications" -maxdepth 3 -type l -print0 2>/dev/null)

(( removed > 0 )) || echo "    nada para limpar"

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
# o upower precisa estar rodando antes da barra: o Quickshell tenta falar com
# ele ao iniciar e, se o serviço ainda não estiver ativo, desiste de vez (a
# bateria some do módulo Sistema até reiniciar a barra).
enable_service upower.service
enable_service power-profiles-daemon.service

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
echo "  - SUPER + SPACE abre o lançador; o app Configurações leva a todo o resto."
