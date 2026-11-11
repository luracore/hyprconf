# Funções compartilhadas pelos apps de pacotes (Pacman, AUR, Remover).
# Uso: source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

THEME_STATE="$HOME/.local/state/hyprconf/theme"
GROUPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hyprconf/grupos"

# ---- aparência -------------------------------------------------------------

# cores ANSI (o terminal já segue o tema; aqui só os papéis)
C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_ACCENT=$'\e[34m'     # azul do tema
C_OK=$'\e[32m'
C_WARN=$'\e[33m'
C_ERR=$'\e[31m'

title() { printf '\n%s%s%s\n' "$C_BOLD$C_ACCENT" "$*" "$C_RESET"; }
info() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
ok() { printf '%s%s%s\n' "$C_OK" "$*" "$C_RESET"; }
warn() { printf '%s%s%s\n' "$C_WARN" "$*" "$C_RESET"; }
err() { printf '%s%s%s\n' "$C_ERR" "$*" "$C_RESET" >&2; }

pause() {
    printf '\n%s' "${C_DIM}Enter para voltar à lista, Esc para sair${C_RESET}"
    local key
    IFS= read -rsn1 key
    printf '\n'
    [[ $key != $'\e' ]]
}

# pergunta sim/não; padrão "sim"
confirm() {
    local answer
    printf '%s %s[S/n]%s ' "$1" "$C_DIM" "$C_RESET"
    read -r answer
    [[ -z $answer || $answer =~ ^[sSyY] ]]
}

# opções do fzf comuns aos apps, com as cores geradas pelo tema
# (Themes/apply-theme.js -> ~/.local/state/hyprconf/theme/fzf.opts)
fzf_base_opts() {
    local opts=(
        --ansi --layout=reverse --info=inline-right
        --border=none --margin=1,2
        --preview-window='down,60%,border-top,wrap'
        --bind='alt-p:toggle-preview,alt-j:preview-down,alt-k:preview-up'
        --bind='alt-d:preview-page-down,alt-u:preview-page-up'
        --pointer='▌' --marker='┃' --prompt='󰍉  '
    )
    if [[ -r $THEME_STATE/fzf.opts ]]; then
        local colors
        mapfile -t colors < "$THEME_STATE/fzf.opts"
        opts+=("${colors[@]}")
    fi
    printf '%s\n' "${opts[@]}"
}

require() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        command -v "${cmd%%:*}" >/dev/null || missing+=("${cmd#*:}")
    done
    if (( ${#missing[@]} > 0 )); then
        err "Falta instalar: ${missing[*]}"
        err "  sudo pacman -S ${missing[*]}"
        read -rsn1 -p "Aperte uma tecla para sair."
        exit 1
    fi
}

# ---- grupos (metapacotes do usuário) ----------------------------------------
# Cada grupo é uma pasta em $GROUPS_DIR com um PKGBUILD "grupo-<nome>" que só
# depende dos pacotes do grupo. Os pacotes ficam marcados como dependência do
# grupo: removendo o grupo, eles viram órfãos e saem juntos.

groups_list() {
    [[ -d $GROUPS_DIR ]] || return 0
    local dir
    for dir in "$GROUPS_DIR"/*/; do
        [[ -f $dir/PKGBUILD ]] && basename "$dir"
    done
}

# nome livre -> nome de pacote válido (minúsculas, números e "-")
group_slug() {
    local slug
    slug=$(printf '%s' "$1" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null || printf '%s' "$1")
    slug=$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
    printf '%s' "$slug"
}

group_packages() {
    local file="$GROUPS_DIR/$1/PKGBUILD"
    [[ -f $file ]] || return 0
    bash -c 'source "$1"; printf "%s\n" "${depends[@]}"' _ "$file"
}

# nome que pode virar pacote: minúsculas, números e "-" (ex.: "jogos-2026")
group_valid() {
    [[ $1 =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

# escreve o PKGBUILD do grupo com a lista de pacotes
group_write() {
    local name=$1; shift
    group_valid "$name" || { err "Nome de grupo inválido: \"$name\""; return 1; }
    local dir="$GROUPS_DIR/$name"
    mkdir -p "$dir"
    {
        printf '# Grupo "%s": metapacote criado pelos apps de pacotes do hyprconf.\n' "$name"
        printf '# Para instalar em outro PC: copie esta pasta e rode "yay -Bi ." nela.\n\n'
        printf 'pkgname=grupo-%s\n' "$name"
        printf 'pkgver=1\npkgrel=1\n'
        printf 'pkgdesc="Grupo de pacotes: %s"\n' "$name"
        printf 'arch=(any)\nlicense=(custom)\n\n'
        printf 'depends=(\n'
        printf '    %s\n' "$@"
        printf ')\n'
    } > "$dir/PKGBUILD"
}

# (re)instala o metapacote do grupo
group_install() {
    local dir="$GROUPS_DIR/$1"
    (cd "$dir" && makepkg -sif --clean --noconfirm >/dev/null) && rm -f "$dir"/*.pkg.tar.*
}

# acrescenta pacotes (já instalados) a um grupo e os marca como dependência
group_add() {
    local name=$1; shift
    local current
    mapfile -t current < <(group_packages "$name")
    local all
    mapfile -t all < <(printf '%s\n' "${current[@]}" "$@" | grep -v '^$' | sort -u)
    group_write "$name" "${all[@]}" || return 1
    group_install "$name" && sudo pacman -D --asdeps "$@" >/dev/null
}

# escolhe um grupo (ou cria um); imprime o nome escolhido.
# Roda dentro de $(...): só o nome vai para a saída; o resto vai para a tela.
group_pick() {
    local new="+ novo grupo…"
    local opts choice
    mapfile -t opts < <(fzf_base_opts | grep -v -e preview -e 'alt-')
    choice=$( { groups_list; printf '%s\n' "$new"; } |
        fzf "${opts[@]}" --no-multi --height=40% \
            --header="Em qual grupo instalar?  (Esc cancela)" ) || return 1

    if [[ $choice == "$new" ]]; then
        local raw
        printf '\n' >&2
        read -rp "Nome do grupo novo (ex.: jogos, dev, estudo): " raw
        choice=$(group_slug "$raw")
    fi
    group_valid "$choice" || { err "Nome de grupo inválido: \"$choice\""; return 1; }
    printf '%s' "$choice"
}
