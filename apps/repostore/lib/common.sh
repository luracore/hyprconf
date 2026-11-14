# gerado pelo tema (themes/converters/fzf)
FZF_COLORS="$(dirname -- "${BASH_SOURCE[0]}")/../fzf-current.opts"

# ANSI básicas: o terminal já segue o tema
C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_ACCENT=$'\e[34m'
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

confirm() {
    local answer
    printf '%s %s[S/n]%s ' "$1" "$C_DIM" "$C_RESET"
    read -r answer
    [[ -z $answer || $answer =~ ^[sSyY] ]]
}

fzf_base_opts() {
    local opts=(
        --ansi --layout=reverse --info=inline-right
        --border=none --margin=1,2
        --preview-window='right,45%,border-left,wrap'
        --pointer='▌' --marker='┃' --gutter=' ' --prompt='󰍉  '
    )
    if [[ -r $FZF_COLORS ]]; then
        local colors
        mapfile -t colors < "$FZF_COLORS"
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

# O -T, como o -Q, aceita um nome que um pacote instalado provê (ex.: "sh" ->
# bash); por isso não dá para comparar com a lista do pacman -Qq.
pkgs_missing() {
    (( $# )) || return 0
    pacman -T "$@"
    return 0
}

# Pacotes que não se remove sem querer: sem eles o sistema não inicia, não
# atualiza ou fica sem rede/vídeo.
SYSTEM_PATTERN='^(base|base-devel|linux(-lts|-zen|-hardened)?(-headers)?|linux-firmware.*|.*-ucode|grub|efibootmgr|systemd-boot.*|refind|limine|mkinitcpio|dracut|sudo|doas|pacman|glibc|systemd|filesystem|networkmanager|iwd|dhcpcd|nvidia.*|mesa|vulkan-.*|xf86-video-.*|btrfs-progs|e2fsprogs|dosfstools|cryptsetup|lvm2)$'

is_system_pkg() {
    [[ $1 =~ $SYSTEM_PATTERN ]]
}

list_installed() {
    local scope=${1:-all}
    local -A version aur
    local p v
    while read -r p; do aur[$p]=1; done < <(pacman -Qqm)
    while read -r p v; do version[$p]=$v; done < <(pacman -Q)

    {
        # sobras primeiro: é o que você provavelmente quer limpar
        pacman -Qdtq | sed 's/$/\torphan/'
        pacman -Qqe | sed 's/$/\texplicit/'
    } | awk -F'\t' '!seen[$1]++' | while IFS=$'\t' read -r p kind; do
        [[ -z $p ]] && continue
        local is_aur=0
        [[ -n ${aur[$p]:-} ]] && is_aur=1
        [[ $scope == aur && $is_aur == 0 ]] && continue
        [[ $scope == repo && $is_aur == 1 ]] && continue

        local tags=""
        [[ $kind == orphan ]] && tags+="${C_WARN}[sobrando]${C_RESET} "
        [[ $scope == all ]] && (( is_aur )) && tags+="${C_ACCENT}[AUR]${C_RESET} "
        is_system_pkg "$p" && tags+="${C_ERR}[sistema]${C_RESET} "
        printf '%-30s %s%-16s%s %s\n' "$p" "$C_DIM" "${version[$p]:-}" "$C_RESET" "$tags"
    done
}

preview_installed() {
    local pkg=$1 info
    info=$(pacman -Qi "$pkg" 2>/dev/null) || return 1
    is_system_pkg "$pkg" && printf '%sPacote de sistema: remover pode impedir o PC de iniciar ou atualizar.%s\n\n' "$C_ERR" "$C_RESET"
    printf '%s\n' "$info" | paint
}

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
