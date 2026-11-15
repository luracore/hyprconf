#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

PREPARED_PATHS=()

# Defaults que não são links, para aparecerem na pergunta do instalador.
EXTRA_DEFAULTS=(fastfetch)

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

warn() {
  echo "    aviso: $*" >&2
}

# Pergunta sim/não; Enter (ou EOF) conta como sim.
ask() {
  local answer
  read -rp "$1 [S/n] " answer
  [[ ! "$answer" =~ ^[nN] ]]
}

# Lista os nomes dos defaults (links e extras) para o texto da pergunta.
default_names() {
  local names extra

  names="$(awk 'NF && !/^[[:space:]]*#/ { printf "%s%s", sep, $1; sep = ", " }' \
    "$REPO_DIR/defaults/links")"

  for extra in "${EXTRA_DEFAULTS[@]}"; do
    names="${names:+$names, }$extra"
  done

  printf '%s' "$names"
}

# ---------------------------------------------------------------------------
# Funções de instalação
# ---------------------------------------------------------------------------

# Prepara um destino antes de sobrescrevê-lo: respeita BACKUP, ignora links
# que já apontam para dentro do repositório e não repete o mesmo caminho.
prepare_destination() {
  local dest="$1"
  local path backup resolved

  for path in "${PREPARED_PATHS[@]}"; do
    [[ "$path" == "$dest" ]] && return 0
  done
  PREPARED_PATHS+=("$dest")

  [[ -e "$dest" || -L "$dest" ]] || return 0

  if [[ -L "$dest" ]]; then
    resolved="$(realpath -m -- "$dest")"
    [[ "$resolved" == "$REPO_DIR" || "$resolved" == "$REPO_DIR"/* ]] && return 0
  fi

  if (( BACKUP )); then
    backup="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$dest" "$backup"
    echo "    backup: $dest -> $backup"
  else
    rm -rf -- "$dest"
    echo "    removido: $dest"
  fi
}

# Cria um link simbólico de $REPO_DIR/$1 para $2.
link() {
  local source="$REPO_DIR/$1"
  local dest="$2"

  if [[ ! -e "$source" ]]; then
    warn "$source não existe; link ignorado"
    return 0
  fi

  mkdir -p "$(dirname -- "$dest")"
  prepare_destination "$dest"
  ln -sfnT "$source" "$dest"
  echo "    link:   $dest -> $source"
}

# Linka a configuração do Hyprland em ~/.config/hypr.
link_hyprland() {
  mkdir -p "$CONFIG_DIR"
  link hypr "$CONFIG_DIR/hypr"
}

# Linka as configurações dos programas listados em defaults/links.
link_defaults() {
  local name dest rest

  while read -r name dest rest; do
    [[ -z "${name:-}" || "$name" == \#* ]] && continue
    link "defaults/$name" "$HOME/$dest"
  done < "$REPO_DIR/defaults/links"
}

# Linka os .desktop do repositório em ~/.local/share/applications.
setup_desktop_shortcuts() {
  local desktop
  local desktops

  mkdir -p "$DATA_DIR/applications"

  shopt -s nullglob
  desktops=("$REPO_DIR"/applications/*.desktop)
  shopt -u nullglob

  for desktop in "${desktops[@]}"; do
    link "applications/$(basename -- "$desktop")" \
      "$DATA_DIR/applications/$(basename -- "$desktop")"
  done
}

# Copia as prioridades iniciais do lançador sem sobrescrever escolhas já feitas.
seed_launcher_pins() {
  local state="$REPO_DIR/apps/quicklauncher/state"
  local defaults="$state/defaults.json"
  local pins="$state/pins.json"

  mkdir -p "$state"

  if [[ ! -e "$pins" && -f "$defaults" ]]; then
    cp -- "$defaults" "$pins"
    echo "    criado: $pins"
  fi
}

# Escreve no dconf as chaves GTK/KDE dos conversores do tema.
apply_dconf() {
  local ini section line key value
  local files

  shopt -s nullglob
  files=("$REPO_DIR"/themes/converters/*/dconf.ini)
  shopt -u nullglob

  (( ${#files[@]} > 0 )) || return 0

  if ! command_exists dconf; then
    warn "dconf não instalado; integrações GTK e KDE ignoradas"
    return 0
  fi

  for ini in "${files[@]}"; do
    section=""

    while IFS= read -r line; do
      case "$line" in
        \[*\])
          section="${line#[}"
          section="${section%]}"
          ;;
        *=*)
          key="${line%%=*}"
          value="${line#*=}"

          if dconf write "/$section/$key" "$value"; then
            echo "    $key = $value"
          else
            warn "não foi possível aplicar $key em $ini"
          fi
          ;;
      esac
    done < <(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$ini")
  done
}

# Dá aos apps Flatpak acesso somente-leitura às cores do GTK4.
setup_flatpak() {
  if ! command_exists flatpak; then
    return 0
  fi

  if flatpak override --user --filesystem=xdg-config/gtk-4.0:ro; then
    echo "    apps Flatpak: acesso às cores do GTK4"
  else
    warn "não foi possível configurar o acesso GTK4 para Flatpak"
  fi
}

# Acrescenta ao ~/.bashrc um bloco que mostra o fastfetch ao abrir o terminal.
# Não cria o arquivo se ele não existir e não duplica um bloco já presente.
setup_fastfetch() {
  local bashrc="$HOME/.bashrc"
  local begin="# >>> hyprconf: fastfetch >>>"
  local end="# <<< hyprconf: fastfetch <<<"

  if [[ ! -f "$bashrc" ]]; then
    warn "$bashrc não existe; nada foi alterado"
  elif grep -qF -- "$begin" "$bashrc"; then
    echo "    já configurado: $bashrc"
  else
    if {
      printf '\n%s\n' "$begin"
      printf '%s\n' 'if [[ $- == *i* ]] && command -v fastfetch >/dev/null; then'
      printf '%s\n' '  fastfetch'
      printf '%s\n' 'fi'
      printf '%s\n' "$end"
    } >> "$bashrc"; then
      echo "    adicionado: $bashrc"
    else
      warn "não foi possível alterar $bashrc"
    fi
  fi
}

# Garante um tema atual, sorteando um se o link ainda não existir.
ensure_theme() {
  local link="$REPO_DIR/themes/current"
  local themes theme

  if [[ -e "$link" ]]; then
    echo "    tema atual: $(basename -- "$(readlink -f -- "$link")")"
    return 0
  fi

  shopt -s nullglob
  themes=("$REPO_DIR"/themes/*.json)
  shopt -u nullglob

  if (( ${#themes[@]} == 0 )); then
    warn "nenhum tema em $REPO_DIR/themes; a barra usará o tema padrão"
    return 0
  fi

  theme="$(basename -- "${themes[RANDOM % ${#themes[@]}]}")"
  ln -sfn "$theme" "$link"
  echo "    tema sorteado: $theme"
}

# Garante um wallpaper atual, sorteando um se o link ainda não existir.
ensure_wallpaper() {
  local link="$REPO_DIR/wallpapers/current"
  local wallpapers wallpaper

  if [[ -e "$link" ]]; then
    echo "    wallpaper atual: $(basename -- "$(readlink -f -- "$link")")"
    return 0
  fi

  shopt -s nullglob nocaseglob
  wallpapers=("$REPO_DIR"/wallpapers/*.{jpg,jpeg,png,webp})
  shopt -u nullglob nocaseglob

  if (( ${#wallpapers[@]} == 0 )); then
    warn "nenhuma imagem em $REPO_DIR/wallpapers; o fundo ficará preto"
    return 0
  fi

  wallpaper="${wallpapers[RANDOM % ${#wallpapers[@]}]}"
  ln -sfn "$wallpaper" "$link"
  echo "    wallpaper sorteado: $(basename -- "$wallpaper")"
}

# Descobre os destinos dos conversores, faz backup deles e aplica o tema.
apply_theme() {
  local targets target resolved

  [[ -e "$REPO_DIR/themes/current" ]] || return 0

  if ! command_exists node; then
    warn "Node.js não instalado; conversores de tema ignorados"
    return 0
  fi

  if ! targets="$(node -e '
    const fs = require("fs");
    const path = require("path");
    const dir = process.argv[1];

    if (!fs.existsSync(dir)) process.exit(0);

    for (const name of fs.readdirSync(dir)) {
      const file = path.join(dir, name, "index.js");

      if (!fs.existsSync(file)) continue;

      const converter = require(file);
      if (converter.target) console.log(converter.target);
    }
  ' "$REPO_DIR/themes/converters")"; then
    warn "não foi possível descobrir os destinos dos conversores"
    return 0
  fi

  while IFS= read -r target; do
    [[ -n "$target" ]] || continue

    resolved="$(realpath -m -- "$target")"
    [[ "$resolved" == "$REPO_DIR" || "$resolved" == "$REPO_DIR"/* ]] && continue

    prepare_destination "$target"
  done <<< "$targets"

  if node "$REPO_DIR/themes/converters/main.js"; then
    echo "    tema aplicado"
  else
    warn "não foi possível aplicar o tema; veja as mensagens acima"
  fi
}

# Desativa a troca automática para o perfil de headset no PipeWire.
setup_bluetooth_audio() {
  if ! command_exists wpctl; then
    warn "wpctl não instalado; configuração de áudio ignorada"
    return 0
  fi

  if wpctl settings --save bluetooth.autoswitch-to-headset-profile false; then
    echo "    troca automática para headset desativada"
  else
    warn "não foi possível ajustar o perfil de áudio (o PipeWire está rodando?)"
  fi
}

# Recarrega o Hyprland para pegar os links recém-criados.
reload_hyprland() {
  if ! command_exists hyprctl; then
    warn "hyprctl não instalado; recarregue o Hyprland manualmente"
    return 0
  fi

  if hyprctl reload; then
    echo "    Hyprland recarregado"
  else
    warn "não foi possível recarregar; recarregue manualmente depois"
  fi
}

print_next_steps() {
  echo
  echo "Hyprconf instalado. Próximos passos:"
  echo "  - saia e entre de novo no Hyprland: a barra, o lançador e as variáveis de"
  echo "    ambiente (como a do qt6ct) só pegam tudo o que foi instalado numa sessão nova;"
  echo "  - abra o nvim uma vez: ele baixa os plugins e o Mason instala os LSPs;"
  echo "  - SUPER + SPACE abre o lançador; o HyprSettings leva a todo o resto."
}

# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------

main() {
  # Verificações iniciais
  if [[ $EUID -eq 0 ]]; then
    echo "Rode este script como seu usuário normal (não como root)." >&2
    exit 1
  fi

  if [[ "$REPO_DIR" != "$HOME/hyprconf" ]]; then
    echo "aviso: o repositório está em $REPO_DIR, mas precisa ficar em ~/hyprconf" >&2
    echo "       (atalhos, startup e seletor apontam para lá). Mova e rode de novo." >&2
    exit 1
  fi

  if ! command_exists node; then
    echo "erro: Node.js não encontrado (dependência do tema; veja o README)." >&2
    exit 1
  fi

  # Preferências: BACKUP e DEFAULTS valem para o resto da instalação.
  ask "Fazer backup do que for substituído?" && BACKUP=1 || BACKUP=0
  ask "Usar os defaults do Hyprconf ($(default_names))?" && DEFAULTS=1 || DEFAULTS=0

  # Configuração do Hyprland
  echo "==> Linkando a configuração do Hyprland"
  link_hyprland

  # Atalhos dos aplicativos
  echo "==> Criando atalhos dos aplicativos"
  setup_desktop_shortcuts

  # Lançador
  echo "==> Aplicando as prioridades iniciais do lançador"
  seed_launcher_pins

  if (( DEFAULTS )); then
    # Configurações dos programas padrão
    echo "==> Linkando as configurações dos programas padrão"
    link_defaults

    # GTK, ícones e cursor
    echo "==> Apontando GTK, ícones e cursor para o tema (gsettings)"
    apply_dconf
    setup_flatpak

    # Fastfetch no ~/.bashrc
    echo "==> Adicionando o fastfetch ao ~/.bashrc"
    setup_fastfetch
  fi

  # Tema e wallpaper atuais
  echo "==> Conferindo o tema e o wallpaper"
  ensure_theme
  ensure_wallpaper

  # Aplicação do tema nos programas
  echo "==> Aplicando o tema"
  apply_theme

  # Áudio
  echo "==> Ajustando o perfil de áudio do Bluetooth"
  setup_bluetooth_audio

  # Sessão
  echo "==> Recarregando o Hyprland"
  reload_hyprland

  print_next_steps
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
