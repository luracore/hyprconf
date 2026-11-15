has_yay() { command -v yay >/dev/null; }

fetch_aur() {
    has_yay || return 0
    local tmp; tmp=$(mktemp "$STATE/aur.XXXXXX")
    LC_ALL=C yay -Sl aur 2>/dev/null | awk '{ print $2 }' > "$tmp" && mv -f "$tmp" "$STATE/aur.list"
}

list_aur() {
    [[ -s $STATE/aur.list ]] || fetch_aur
    awk -v ok="$C_OK" -v dim="$C_DIM" -v reset="$C_RESET" '
        FILENAME == ARGV[1] { installed[$1] = $2; next }
        ($1 in installed) { printf "%-30s %s✓%s %s%s%s\n", $1, ok, reset, dim, installed[$1], reset; next }
        { print }' <(pacman -Qm) "$STATE/aur.list"
}

list_aur_updates() {
    LC_ALL=C yay -Qua 2>/dev/null > "$STATE/updates.aur"
    format_updates "$STATE/updates.aur"
}

update_aur() {
    if checkupdates >/dev/null 2>&1; then
        warn "Há atualizações oficiais pendentes: atualize antes pela aba Pacman, em Atualizações."
        info "Os pacotes do AUR são compilados contra as bibliotecas do sistema, que precisam estar atualizadas."
        return
    fi
    if [[ ! -s $STATE/updates.aur ]]; then
        ok "Nada para atualizar no AUR."
        return
    fi
    title "Atualizando os pacotes do AUR"
    info "O yay mostra o que mudou em cada PKGBUILD antes de compilar."
    yay -Sua
}
