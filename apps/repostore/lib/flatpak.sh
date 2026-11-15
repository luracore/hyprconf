FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

has_flatpak() { command -v flatpak >/dev/null; }

fetch_flatpak() {
    has_flatpak || return 0
    flatpak remote-add --user --if-not-exists flathub "$FLATHUB_URL" >/dev/null 2>&1
    local tmp; tmp=$(mktemp "$STATE/flatpak.XXXXXX")
    flatpak remote-ls --user flathub --app --columns=application,name,version 2>/dev/null > "$tmp" &&
        mv -f "$tmp" "$STATE/flatpak.list"
}

list_flatpak() {
    [[ -s $STATE/flatpak.list ]] || fetch_flatpak
    awk -F'\t' -v ok="$C_OK" -v dim="$C_DIM" -v reset="$C_RESET" '
        FILENAME == ARGV[1] { installed[$1] = 1; next }
        { printf "%-42s %s %s%s  %s%s\n", $1, (($1 in installed) ? ok "✓" reset : " "), "", $2, dim $3, reset }
    ' <(flatpak list --user --app --columns=application 2>/dev/null) "$STATE/flatpak.list"
}

list_flatpak_installed() {
    flatpak list --user --app --columns=application,name,version 2>/dev/null |
        awk -F'\t' -v dim="$C_DIM" -v reset="$C_RESET" '{ printf "%-42s %s  %s%s%s\n", $1, $2, dim, $3, reset }'
}

list_flatpak_updates() {
    flatpak remote-ls --user --updates --app --columns=application,name,version 2>/dev/null |
        awk -F'\t' -v ok="$C_OK" -v reset="$C_RESET" '{ printf "%-42s %s  → %s%s%s\n", $1, $2, ok, $3, reset }'
}

flatpak_enter() {
    if (( $# == 1 )) && flatpak info --user "$1" >/dev/null 2>&1; then
        set_screen flatpak:installed
        printf '%s' "$1" > "$STATE/query"
        return 1
    fi
    local missing=() app
    for app in "$@"; do
        flatpak info --user "$app" >/dev/null 2>&1 || missing+=("$app")
    done
    if (( ${#missing[@]} == 0 )); then
        ok "Já estão todos instalados: ${*}"
        return 0
    fi
    title "Instalando do Flathub: ${missing[*]}"
    flatpak install --user flathub "${missing[@]}"
}
