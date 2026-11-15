PREVIEW_NORMAL='right,35%,border-left,wrap'
PREVIEW_MAX='right,99%,border-left,wrap'

screen() { cat "$STATE/screen" 2>/dev/null || echo pacman:all; }
set_screen() { echo "$1" > "$STATE/screen"; }
origin() { cat "$STATE/prev" 2>/dev/null || echo pacman:all; }

toggle_zoom() {
    is_text "$(screen)" && return
    if [[ -f $STATE/zoom ]]; then
        rm -f "$STATE/zoom"
        printf 'change-preview-window(%s)' "$PREVIEW_NORMAL"
    else
        touch "$STATE/zoom"
        printf 'change-preview-window(%s)' "$PREVIEW_MAX"
    fi
}

available() {
    case $1 in
        aur) has_yay ;;
        flatpak) has_flatpak ;;
        *) return 0 ;;
    esac
}

is_text() { [[ $1 == help || $1 == *:missing ]]; }
source_of() { case $1 in pacman:*|aur:*|flatpak:*) echo "${1%%:*}" ;; esac; }
mode_of() { case $1 in pacman:*|aur:*|flatpak:*) echo "${1#*:}" ;; esac; }

missing_lines() {
    local b=$C_BOLD a=$C_ACCENT d=$C_DIM w=$C_WARN r=$C_RESET
    printf '\n'
    case $1 in
        flatpak)
            printf '  %sO flatpak não está instalado.%s\n\n' "$b" "$r"
            printf '  Instalação:\n\n'
            printf '    1- Instale o flatpak pelo Pacman\n\n'
            printf '    2- Saia e entre na sessão\n\n'
            printf '  O RepoStore adiciona o Flathub sozinho.\n\n' ;;
        aur)
            printf '  %sO yay não está instalado.%s\n\n' "$b" "$r"
            printf '  O AUR tem pacotes enviados pela comunidade, fora dos repositórios\n'
            printf '  oficiais. O RepoStore usa o yay para buscar, instalar e atualizar.\n\n'
            printf '  %sO yay também vem do AUR: o makepkg roda o PKGBUILD dele.%s\n' "$w" "$r"
            printf '  Para instalar, num terminal:\n\n'
            printf '    %ssudo pacman -S --needed git base-devel%s\n' "$a" "$r"
            printf '    %sgit clone https://aur.archlinux.org/yay-bin.git%s\n' "$a" "$r"
            printf '    %scd yay-bin && makepkg -si%s\n\n' "$a" "$r"
            printf '  %sDepois, troque de aba e volte.%s\n' "$d" "$r" ;;
    esac
}

list() {
    local scr out
    scr=$(screen)
    case $scr in
        *:missing) missing_lines "${scr%%:*}"; return ;;
        pacman:all) out=$(list_pacman) ;;
        pacman:installed) out=$(list_installed repo) ;;
        pacman:updates) out=$(list_pacman_updates) ;;
        aur:all) out=$(list_aur) ;;
        aur:installed) out=$(list_installed aur) ;;
        aur:updates) out=$(list_aur_updates) ;;
        flatpak:all) out=$(list_flatpak) ;;
        flatpak:installed) out=$(list_flatpak_installed) ;;
        flatpak:updates) out=$(list_flatpak_updates) ;;
        help) help_lines; return ;;
    esac
    if [[ -n $out ]]; then
        printf '%s\n' "$out"
    else
        printf '%s— %s%s\n' "$C_DIM" "$(empty_message "$scr")" "$C_RESET"
    fi
}

cached() {
    local file="$STATE/preview/$1"; shift
    if [[ ! -s $file ]]; then
        mkdir -p "$STATE/preview"
        "$@" 2>/dev/null > "$file.tmp" && mv -f "$file.tmp" "$file"
    fi
    cat "$file" 2>/dev/null
}

preview_package() {
    local item=$1 src=$2
    preview_installed "$item" && return
    if [[ $src == aur ]]; then
        printf '%sAUR: pacote enviado pela comunidade. O yay mostra o PKGBUILD para revisar antes de instalar.%s\n\n' "$C_WARN" "$C_RESET"
        cached "aur-$item" yay -Si --aur "$item" | paint
    else
        pacman -Si "$item" 2>/dev/null | paint
    fi
}

preview_update() {
    local item=$1 file=$2 old new
    read -r _ old _ new < <(grep -h -m1 "^$item " "$file" 2>/dev/null) &&
        printf '%s%s%s  %s → %s%s%s\n\n' "$C_BOLD" "$item" "$C_RESET" "$old" "$C_OK" "$new" "$C_RESET"
}

preview() {
    local item=$1 scr
    [[ $item == "—" ]] && return
    scr=$(screen)
    is_text "$scr" && return
    case $scr in
        pacman:all|pacman:installed) preview_package "$item" pacman ;;
        aur:all|aur:installed) preview_package "$item" aur ;;
        pacman:updates)
            preview_update "$item" "$STATE/updates"
            pacman -Si "$item" 2>/dev/null | paint ;;
        aur:updates)
            preview_update "$item" "$STATE/updates.aur"
            cached "aur-$item" yay -Si --aur "$item" | paint ;;
        flatpak:*)
            local details
            if details=$(flatpak info --user "$item" 2>/dev/null); then
                printf '%s✓ instalado%s\n\n' "$C_OK" "$C_RESET"
                printf '%s\n' "$details" | paint
            else
                cached "flatpak-$item" flatpak remote-info --user flathub "$item" | paint
            fi ;;
    esac
}

tabs() { printf '%s\n' pacman aur flatpak; }
tab_of() { source_of "$1"; }
tab_label() { case $1 in pacman) echo "Pacman" ;; aur) echo "AUR" ;; flatpak) echo "Flatpak" ;; esac; }

tabs_header() {
    local current out="" t
    current=$(tab_of "$1")
    while read -r t; do
        if [[ $t == "$current" ]]; then
            out+="${C_BOLD}${C_ACCENT}"$'\e[4m'"$(tab_label "$t")${C_RESET}   "
        else
            out+="${C_DIM}$(tab_label "$t")${C_RESET}   "
        fi
    done < <(tabs)
    out+="  ${C_DIM}(Ctrl+H para Ajuda)${C_RESET}"
    printf '%s' "$out"
}

screen_for_tab() {
    local tab=$1 mode
    available "$tab" || { echo "$tab:missing"; return; }
    mode=$(mode_of "$2")
    [[ $mode == missing ]] && mode=all
    echo "$tab:${mode:-all}"
}

tab_step() {
    local list current i n
    mapfile -t list < <(tabs)
    n=${#list[@]}
    current=$(tab_of "$1")
    for i in "${!list[@]}"; do
        [[ ${list[$i]} == "$current" ]] && { screen_for_tab "${list[$(( (i + $2 + n) % n ))]}" "$1"; return; }
    done
    echo pacman:all
}

mode_cycle() {
    local src dir mode
    src=$(source_of "$1")
    dir=${2:-forward}
    mode=$(mode_of "$1")
    [[ -n $src && $1 != *:missing ]] || return

    case $mode in
        all)
            if [[ $dir == forward ]]; then echo "$src:installed"; else echo "$src:updates"; fi ;;
        installed)
            if [[ $dir == forward ]]; then echo "$src:updates"; else echo "$src:all"; fi ;;
        updates)
            if [[ $dir == forward ]]; then echo "$src:all"; else echo "$src:installed"; fi ;;
        *)
            echo "$src:all" ;;
    esac
}

screen_by_label() {
    local t
    while read -r t; do
        [[ $(tab_label "$t") == "$1" ]] && { screen_for_tab "$t" "$2"; return; }
    done < <(tabs)
}

prompt_for() {
    case $1 in
        *:all) echo "󰍉  " ;;
        *:installed) echo "󰏗 instalados  " ;;
        *:updates) echo "󰚰 atualizações  " ;;
        help|*:missing) echo "" ;;
    esac
}

ghost_for() { echo "Digite aqui"; }

empty_message() {
    case $1 in
        aur:all) echo "Não foi possível listar o AUR (sem internet?)." ;;
        flatpak:all) echo "Não foi possível listar o Flathub (sem internet?)." ;;
        *:updates) echo "Tudo atualizado." ;;
        pacman:installed|aur:installed) echo "Nenhum pacote seu aqui." ;;
        flatpak:installed) echo "Nenhum app Flatpak instalado." ;;
        *) echo "Nada aqui." ;;
    esac
}

help_lines() {
    local commands=(
        "Alt+P / Alt+A / Alt+F|Pacman / AUR / Flatpak"
        "← / → ou Alt+H/L|aba principal anterior / próxima"
        "Tab / Shift+Tab|alterna filtro interno (Todos/Instalados/Atualizações)"
        "↑ / ↓ ou Alt+J/K|pacote anterior / próximo"
        "Enter|maximiza / normaliza os detalhes"
        "Alt+M|marca / desmarca o pacote"
        "Alt+I|instala o(s) selecionado(s)"
        "Alt+R|remove o(s) selecionado(s)"
        "Alt+C|limpa órfãos / runtimes sem uso"
        "Alt+U|atualiza o sistema / ecossistema"
        "Ctrl+H|exibe esta ajuda"
        "Esc|sai"
    )

    local kw=0 dw=0 row k d
    for row in "${commands[@]}"; do
        k=${row%%|*} d=${row#*|}
        (( ${#k} > kw )) && kw=${#k}
        (( ${#d} > dw )) && dw=${#d}
    done

    local rows cols
    read -r rows cols < <(stty size 2>/dev/null </dev/tty || echo "40 120")
    local height=$(( ${#commands[@]} + 5 ))
    local top=$(( (rows - height) / 2 - 2 )) left=$(( (cols - kw - dw - 7) / 2 - 2 ))
    (( top < 0 )) && top=0
    (( left < 0 )) && left=0
    local pad; pad=$(printf '%*s' "$left" '')

    local line_k line_d
    line_k=$(printf '─%.0s' $(seq $((kw + 2))))
    line_d=$(printf '─%.0s' $(seq $((dw + 2))))

    table() {
        local name=$1; shift
        printf '%s%s%s%s\n' "$pad" "$C_BOLD$C_ACCENT" "$name" "$C_RESET"
        printf '%s%s╭%s┬%s╮%s\n' "$pad" "$C_DIM" "$line_k" "$line_d" "$C_RESET"
        local r
        for r in "$@"; do
            k=${r%%|*} d=${r#*|}
            printf '%s%s│%s %s%s%*s%s %s│%s %s%*s %s│%s\n' "$pad" \
                "$C_DIM" "$C_RESET" "$C_ACCENT" "$k" $((kw - ${#k})) "" "$C_RESET" \
                "$C_DIM" "$C_RESET" "$d" $((dw - ${#d})) "" "$C_DIM" "$C_RESET"
        done
        printf '%s%s╰%s┴%s╯%s\n' "$pad" "$C_DIM" "$line_k" "$line_d" "$C_RESET"
    }

    local i
    for (( i = 0; i < top; i++ )); do printf '\n'; done
    table "Comandos" "${commands[@]}"; printf '\n'
    printf '%s%sEsc volta%s\n' "$pad" "$C_DIM" "$C_RESET"
}

show_actions() {
    local target=$1
    set_screen "$target"
    rm -f "$STATE/zoom"
    local header
    if [[ $target == help ]]; then header=$(tabs_header "$(origin)"); else header=$(tabs_header "$target"); fi
    printf 'change-header(%s)+change-prompt(%s)+change-ghost(%s)' \
        "$header" "$(prompt_for "$target")" "$(ghost_for "$target")"
    printf '+change-preview-window(%s)' "$PREVIEW_NORMAL"
    if is_text "$target"; then
        rm -f "$STATE/pending"
        touch "$STATE/text"
        printf '+disable-search+clear-query+hide-input+hide-preview+change-pointer( )+reload(%s --list)+first' "$SELF"
    else
        rm -f "$STATE/text"
        touch "$STATE/pending" "$STATE/clear"
        printf '+enable-search+clear-query+hide-input+hide-preview+change-pointer( )+reload(%s --loading)' "$SELF"
    fi
}

on_load() {
    if [[ -f $STATE/pending ]]; then
        rm -f "$STATE/pending"
        printf 'reload(%s --list)' "$SELF"
    elif ! is_text "$(screen)"; then
        printf 'show-input+show-preview+change-pointer(▌)+first'
        if [[ -f $STATE/clear ]]; then
            rm -f "$STATE/clear"
            printf '+clear-query'
        fi
    fi
}

nav_base() {
    local scr; scr=$(screen)
    [[ $scr == help ]] && scr=$(origin)
    echo "$scr"
}

tab_cmd() {
    local base target
    base=$(nav_base)
    case $1 in
        prev) target=$(tab_step "$base" -1) ;;
        next) target=$(tab_step "$base" 1) ;;
        index:*) target=$(tabs | sed -n "${1#index:}p") && [[ -n $target ]] && target=$(screen_for_tab "$target" "$base") ;;
        label:*) target=$(screen_by_label "${1#label:}" "$base") ;;
    esac
    [[ -n $target ]] && show_actions "$target"
}

mode_cmd() {
    local target
    case $1 in
        cycle-forward) target=$(mode_cycle "$(nav_base)" forward) ;;
        cycle-backward) target=$(mode_cycle "$(nav_base)" backward) ;;
    esac
    [[ -n $target ]] && show_actions "$target"
}

action_valid() {
    case "$2" in
        alt-i|alt-r|alt-c|alt-u) return 0 ;;
    esac
    return 1
}

accept_with() {
    printf 'execute-silent(echo %s > %s/key)+accept' "$1" "$STATE"
}

key_cmd() {
    local key=$1; shift
    local scr; scr=$(screen)
    case $key in
        esc)
            [[ $scr == help ]] && show_actions "$(origin)" || printf 'abort' ;;
        ctrl-h)
            if [[ $scr == help ]]; then
                show_actions "$(origin)"
            else
                echo "$scr" > "$STATE/prev"
                show_actions help
            fi ;;
        *)
            action_valid "$scr" "$key" && accept_with "$key" ;;
    esac
}

handle() {
    local key=$1; shift
    local items=("$@")
    local scr; scr=$(screen)
    local tab; tab=$(source_of "$scr")

    case "$key" in
        alt-i)
            (( ${#items[@]} )) || return 1
            if [[ $tab == flatpak ]]; then
                flatpak_enter "${items[@]}" || return 1
            else
                search_enter "$tab" "${items[@]}" || return 1
            fi
            ;;
        alt-r)
            (( ${#items[@]} )) || return 1
            if [[ $tab == flatpak ]]; then
                local installed=() app
                for app in "${items[@]}"; do flatpak info --user "$app" >/dev/null 2>&1 && installed+=("$app"); done
                (( ${#installed[@]} )) || { info "Nenhum deles está instalado."; return 0; }
                title "Removendo: ${installed[*]}"
                flatpak uninstall --user "${installed[@]}"
            else
                local installed
                mapfile -t installed < <(only_installed "${items[@]}")
                (( ${#installed[@]} )) && remove_packages "${installed[@]}"
            fi
            ;;
        alt-c)
            if [[ $tab == flatpak ]]; then
                title "Removendo os runtimes que nenhum app usa"
                flatpak uninstall --user --unused
            else
                clean_orphans
            fi
            ;;
        alt-u)
            if [[ $tab == flatpak ]]; then
                title "Atualizando os apps e runtimes do Flatpak"
                flatpak update --user
            elif [[ $tab == aur ]]; then
                update_aur
            else
                update_system
            fi
            ;;
        *) return 1 ;;
    esac
    return 0
}
