# Funções do app Pacotes (apps/hyprconf-pacotes).
# Uso: source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

THEME_STATE="$HOME/.local/state/hyprconf/theme"
GROUPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hyprconf/grupos"
SETUP_META="hyprconf-deps"

# ---- aparência -------------------------------------------------------------

# cores ANSI (o terminal já segue o tema; aqui só os papéis)
C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_ACCENT=$'\e[34m'
C_OK=$'\e[32m'
C_WARN=$'\e[33m'
C_ERR=$'\e[31m'
C_MAGENTA=$'\e[35m'

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
        --preview-window='right,45%,border-left,wrap'
        --pointer='▌' --marker='┃' --gutter=' ' --prompt='󰍉  '
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

# realça os nomes dos campos ("Nome            :") da saída do pacman
paint() {
    sed -E "s/^([^ :][^:]*[^ :]) *:/${C_ACCENT}&${C_RESET}/"
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

# nome que pode virar pacote: minúsculas, números e "-" (ex.: "jogos-2026")
group_valid() {
    [[ $1 =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

group_packages() {
    local file="$GROUPS_DIR/$1/PKGBUILD"
    [[ -f $file ]] || return 0
    bash -c 'source "$1"; printf "%s\n" "${depends[@]}"' _ "$file" | grep -v '^$'
}

# "pacote<TAB>grupo" de todos os grupos
groups_membership() {
    local group
    while read -r group; do
        group_packages "$group" | sed "s/\$/\t$group/"
    done < <(groups_list)
}

# grupo de um pacote (vazio se não estiver em nenhum)
group_of() {
    groups_membership | awk -F'\t' -v p="$1" '$1 == p { print $2; exit }'
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

# gera o metapacote do grupo (sem instalar, sem senha); imprime o arquivo
group_build() {
    local dir="$GROUPS_DIR/$1"
    rm -f "$dir"/*.pkg.tar.*
    (cd "$dir" && makepkg -fd --clean >/dev/null 2>&1) || { err "Não foi possível gerar o grupo \"$1\"."; return 1; }
    ls "$dir"/*.pkg.tar.* 2>/dev/null | head -1
}

# Uma senha só: tudo que precisa de root vai num único sudo.
#   root_run 'comandos com "$@"' args...
root_run() {
    local script=$1; shift
    sudo bash -c "set -e; $script" _ "$@"
}

# o metapacote do grupo está instalado? (um grupo só atribuído ainda não está)
group_meta_installed() {
    pacman -Qq "grupo-$1" >/dev/null 2>&1
}

# pacotes do grupo que ainda não estão instalados
group_missing() {
    local p
    while read -r p; do
        pacman -Qq "$p" >/dev/null 2>&1 || echo "$p"
    done < <(group_packages "$1")
}

# atribui pacotes a um grupo, só no PKGBUILD (sem instalar, sem senha)
group_assign() {
    local name=$1; shift
    local current all
    mapfile -t current < <(group_packages "$name")
    mapfile -t all < <(printf '%s\n' "${current[@]}" "$@" | grep -v '^$' | sort -u)
    group_write "$name" "${all[@]}"
}

# o pacote existe nos repositórios oficiais? (senão, é do AUR)
in_repos() {
    pacman -Si "$1" >/dev/null 2>&1
}

# aplica o grupo: o pacman instala o metapacote e traz junto o que faltar dos
# repositórios; depois todos os pacotes do grupo viram dependência dele.
# O pacman não instala do AUR: os do AUR que faltam vêm antes, pelo yay.
group_apply() {
    local name=$1
    local pkgs pkg aur=() p
    mapfile -t pkgs < <(group_packages "$name")
    while read -r p; do
        in_repos "$p" || aur+=("$p")
    done < <(group_missing "$name")
    if (( ${#aur[@]} > 0 )); then
        command -v yay >/dev/null || { err "Falta o yay para instalar do AUR: ${aur[*]}"; return 1; }
        title "Do AUR (pelo yay): ${aur[*]}"
        yay -S --needed --asdeps "${aur[@]}" || return 1
    fi
    pkg=$(group_build "$name") || return 1
    root_run 'f=$1; shift; pacman -U "$f"; (( $# )) && pacman -D --asdeps "$@" >/dev/null; true' "$pkg" "${pkgs[@]}"
    local status=$?
    rm -f "$pkg"
    return $status
}

# atribui e aplica (Alt+Enter na aba Repositórios). Se você recusar no pacman,
# o grupo volta a ser o que era.
group_add() {
    local name=$1; shift
    local dir="$GROUPS_DIR/$name" backup=""
    [[ -f $dir/PKGBUILD ]] && backup=$(cat "$dir/PKGBUILD")
    group_assign "$name" "$@" || return 1
    if ! group_apply "$name"; then
        if [[ -n $backup ]]; then printf '%s\n' "$backup" > "$dir/PKGBUILD"; else rm -rf "${dir:?}"; fi
        return 1
    fi
}

# tira pacotes de um grupo; eles continuam instalados, como avulsos.
# Se o grupo ficar vazio, ele é desfeito.
group_drop() {
    local name=$1; shift
    local rest pkg installed=()
    mapfile -t rest < <(group_packages "$name" | grep -vxF -f <(printf '%s\n' "$@"))
    local p
    for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 && installed+=("$p"); done

    if ! group_meta_installed "$name"; then
        # grupo ainda não aplicado: só o PKGBUILD muda
        if (( ${#rest[@]} == 0 )); then rm -rf "${GROUPS_DIR:?}/$name"; else group_write "$name" "${rest[@]}"; fi
        return
    fi

    if (( ${#rest[@]} == 0 )); then
        root_run 'g=$1; shift; (( $# )) && pacman -D --asexplicit "$@" >/dev/null; pacman -R --noconfirm "$g" >/dev/null' \
            "grupo-$name" "${installed[@]}" && rm -rf "${GROUPS_DIR:?}/$name"
    else
        group_write "$name" "${rest[@]}" && pkg=$(group_build "$name") || return 1
        root_run 'f=$1; shift; (( $# )) && pacman -D --asexplicit "$@" >/dev/null; pacman -U --noconfirm "$f" >/dev/null' \
            "$pkg" "${installed[@]}"
        local status=$?
        rm -f "$pkg"
        return $status
    fi
}

# desfaz o grupo: os pacotes ficam instalados, como avulsos
group_dissolve() {
    local name=$1
    if ! group_meta_installed "$name"; then
        rm -rf "${GROUPS_DIR:?}/$name"
        return
    fi
    local pkgs=() p
    while read -r p; do pacman -Qq "$p" >/dev/null 2>&1 && pkgs+=("$p"); done < <(group_packages "$name")
    root_run 'g=$1; shift; (( $# )) && pacman -D --asexplicit "$@" >/dev/null; pacman -R --noconfirm "$g" >/dev/null' \
        "grupo-$name" "${pkgs[@]}" && rm -rf "${GROUPS_DIR:?}/$name"
}

# apaga o grupo e os pacotes dele (e as dependências que só eles usavam)
group_delete() {
    local name=$1
    if group_meta_installed "$name"; then
        sudo pacman -Rns "grupo-$name" && rm -rf "${GROUPS_DIR:?}/$name"
        return
    fi
    # grupo não aplicado: remove os pacotes dele que estiverem instalados
    local pkgs=() p
    while read -r p; do pacman -Qq "$p" >/dev/null 2>&1 && pkgs+=("$p"); done < <(group_packages "$name")
    if (( ${#pkgs[@]} > 0 )); then
        sudo pacman -Rns "${pkgs[@]}" || return 1
    fi
    rm -rf "${GROUPS_DIR:?}/$name"
}

# escolhe um grupo (ou cria um); imprime o nome escolhido.
# Roda dentro de $(...): só o nome vai para a saída; o resto vai para a tela.
group_pick() {
    local new="+ novo grupo…"
    local opts choice
    mapfile -t opts < <(fzf_base_opts | grep -v -e preview -e 'alt-' -e footer)
    choice=$( { groups_list; printf '%s\n' "$new"; } |
        fzf "${opts[@]}" --no-multi --height=40% \
            --header="Em qual grupo?  (Esc cancela)" ) || return 1

    if [[ $choice == "$new" ]]; then
        local raw
        printf '\n' >&2
        read -rp "Nome do grupo novo (ex.: jogos, dev, estudo): " raw
        choice=$(group_slug "$raw")
    fi
    group_valid "$choice" || { err "Nome de grupo inválido: \"$choice\""; return 1; }
    printf '%s' "$choice"
}

# ---- instalados (tela "Instalados" do Pacman e do AUR) ----------------------

# Pacotes que não se remove sem querer: sem eles o sistema não inicia, não
# atualiza ou fica sem rede/vídeo.
SYSTEM_PATTERN='^(base|base-devel|linux(-lts|-zen|-hardened)?(-headers)?|linux-firmware.*|.*-ucode|grub|efibootmgr|systemd-boot.*|refind|limine|mkinitcpio|dracut|sudo|doas|pacman|glibc|systemd|filesystem|networkmanager|iwd|dhcpcd|nvidia.*|mesa|vulkan-.*|xf86-video-.*|btrfs-progs|e2fsprogs|dosfstools|cryptsetup|lvm2)$'

is_system_pkg() {
    [[ $1 =~ $SYSTEM_PATTERN ]]
}

# pacotes que pertencem ao setup (dependências do hyprconf-deps)
setup_packages() {
    LC_ALL=C pacman -Qi "$SETUP_META" 2>/dev/null |
        awk -F': ' '/^Depends On/ { print $2 }' | tr -s ' ' '\n' | sed 's/[<>=].*//' | grep -v -e '^$' -e '^None$'
}

# Lista os pacotes que são "seus": avulsos (explícitos), os dos seus grupos e
# as sobras (órfãos). Os do hyprconf ficam de fora (gerencie pelo PKGBUILD).
# scope: "all" ou "aur" (só os de fora dos repositórios oficiais)
list_installed() {
    local scope=${1:-all}
    local aur
    aur=$(pacman -Qqm)

    local -A group setup version
    local p g v
    while IFS=$'\t' read -r p g; do group[$p]=$g; done < <(groups_membership)
    while read -r p; do setup[$p]=1; done < <(setup_packages)
    while read -r p v; do version[$p]=$v; done < <(pacman -Q)

    {
        # sobras primeiro: é o que você provavelmente quer limpar
        pacman -Qdtq | sed 's/$/\torphan/'
        pacman -Qqe | sed 's/$/\texplicit/'
        printf '%s\n' "${!group[@]}" | sed 's/$/\tgroup/'
    } | awk -F'\t' '!seen[$1]++' | while IFS=$'\t' read -r p kind; do
        [[ -z $p || $p == grupo-* || $p == "$SETUP_META" || -n ${setup[$p]:-} ]] && continue
        local is_aur=0
        grep -qxF "$p" <<< "$aur" && is_aur=1
        [[ $scope == aur && $is_aur == 0 ]] && continue

        local tags=""
        [[ $kind == orphan ]] && tags+="${C_WARN}[sobrando]${C_RESET} "
        [[ -n ${group[$p]:-} ]] && tags+="${C_MAGENTA}[grupo: ${group[$p]}]${C_RESET} "
        (( is_aur )) && tags+="${C_ACCENT}[AUR]${C_RESET} "
        is_system_pkg "$p" && tags+="${C_ERR}[sistema]${C_RESET} "
        printf '%-30s %s%-16s%s %s\n' "$p" "$C_DIM" "${version[$p]:-}" "$C_RESET" "$tags"
    done
}

preview_installed() {
    local pkg=$1
    local g
    g=$(group_of "$pkg")
    [[ -n $g ]] && printf '%sNo grupo "%s".%s\n\n' "$C_MAGENTA" "$g" "$C_RESET"
    is_system_pkg "$pkg" && printf '%sPacote de sistema: remover pode impedir o PC de iniciar ou atualizar.%s\n\n' "$C_ERR" "$C_RESET"
    pacman -Qi "$pkg" 2>/dev/null | paint
}

# remove pacotes (tirando antes dos grupos); pede o nome para os de sistema
remove_packages() {
    local pkgs=("$@")
    local p
    for p in "${pkgs[@]}"; do
        if is_system_pkg "$p"; then
            warn "\"$p\" é um pacote de sistema: sem ele o PC pode não iniciar ou não atualizar."
            local typed
            read -rp "Para remover mesmo assim, digite o nome dele: " typed
            [[ $typed == "$p" ]] || { info "Cancelado."; return 1; }
        fi
    done

    # pacotes em grupos: saem do grupo antes (senão o pacman recusa)
    local -A by_group
    local pkg g
    while IFS=$'\t' read -r pkg g; do by_group[$pkg]=$g; done < <(groups_membership)
    for p in "${pkgs[@]}"; do
        if [[ -n ${by_group[$p]:-} ]]; then
            info "Tirando \"$p\" do grupo \"${by_group[$p]}\"…"
            group_drop "${by_group[$p]}" "$p" || return 1
        fi
    done

    title "Removendo: ${pkgs[*]}"
    sudo pacman -Rns "${pkgs[@]}"
}

clean_orphans() {
    local orphans
    mapfile -t orphans < <(pacman -Qdtq)
    if (( ${#orphans[@]} == 0 )); then
        ok "Nada sobrando."
        return
    fi
    title "Removendo ${#orphans[@]} pacote(s) sobrando"
    sudo pacman -Rns "${orphans[@]}"
}
