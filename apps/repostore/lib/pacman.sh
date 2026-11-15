# Lógica específica do Pacman

list_pacman() {
    LC_ALL=C pacman -Sl | awk -v ok="$C_OK" -v dim="$C_DIM" -v reset="$C_RESET" '{
        mark = ($4 ~ /installed/) ? ok "✓" reset : " "
        printf "%-30s %s %s%-16s %s%s\n", $2, mark, dim, $3, $1, reset
    }'
}

list_pacman_updates() {
    checkupdates 2>/dev/null > "$STATE/updates"
    format_updates "$STATE/updates"
}

format_updates() {
    awk -v dim="$C_DIM" -v ok="$C_OK" -v reset="$C_RESET" 'NF >= 4 {
        printf "%-30s %s%-16s%s → %s%s%s\n", $1, dim, $2, reset, ok, $4, reset
    }' "$1"
}

only_installed() {
    local -A missing
    local p
    while read -r p; do missing[$p]=1; done < <(pkgs_missing "$@")
    for p in "$@"; do
        if [[ -z ${missing[$p]:-} ]]; then echo "$p"; else info "\"$p\" não está instalado." >&2; fi
    done
}

search_enter() {
    local src=$1; shift
    if (( $# == 1 )) && pacman -Qq "$1" >/dev/null 2>&1; then
        set_screen "$src:installed"
        printf '%s' "$1" > "$STATE/query"
        return 1
    fi
    local missing
    mapfile -t missing < <(pkgs_missing "$@")
    if (( ${#missing[@]} == 0 )); then
        ok "Já estão todos instalados: ${*}"
        return 0
    fi
    title "Instalando: ${missing[*]}"
    if [[ $src == aur ]]; then
        yay -S --needed "${missing[@]}"
    else
        sudo pacman -S --needed "${missing[@]}"
    fi
}

arch_news() {
    local last
    last=$(grep -a 'starting full system upgrade' /var/log/pacman.log 2>/dev/null | tail -1 | grep -oE '^\[[^]]+\]' | tr -d '[]')
    curl -fsS --max-time 8 https://archlinux.org/feeds/news/ 2>/dev/null |
        LAST="$last" node -e '
            let xml = "";
            process.stdin.on("data", d => xml += d).on("end", () => {
                const since = process.env.LAST ? new Date(process.env.LAST) : new Date(0);
                for (const item of xml.split("<item>").slice(1)) {
                    const get = tag => (item.match(new RegExp("<" + tag + ">([\\s\\S]*?)</" + tag + ">")) || [])[1] || "";
                    const date = new Date(get("pubDate"));
                    if (date > since)
                        console.log(date.toLocaleDateString("pt-BR") + "  " + get("title") + "\n            " + get("link"));
                }
            });'
}

update_system() {
    if [[ ! -s $STATE/updates ]]; then
        ok "Os pacotes oficiais estão em dia."
        return
    fi

    title "Notícias do Arch desde a última atualização"
    local news
    news=$(arch_news)
    if [[ -n $news ]]; then
        warn "$news"
        printf '\n'
        info "Algumas notícias pedem um passo manual antes ou depois de atualizar."
        confirm "Continuar com a atualização?" || return
    else
        info "Nenhuma notícia nova."
    fi

    title "Atualizando os pacotes oficiais"
    sudo pacman -Syu || return

    title "Depois da atualização"
    local nothing=1
    if [[ ! -d /usr/lib/modules/$(uname -r) ]]; then
        warn "O kernel foi atualizado: reinicie para usar o novo."
        nothing=0
    fi
    local pacnew
    pacnew=$(pacdiff -o 2>/dev/null)
    if [[ -n $pacnew ]]; then
        warn "Configurações novas para revisar (.pacnew):"
        printf '  %s\n' $pacnew
        info "  Para comparar e mesclar: sudo DIFFPROG='nvim -d' pacdiff"
        nothing=0
    fi
    local orphans
    orphans=$(pacman -Qdtq | wc -l)
    if (( orphans > 0 )); then
        warn "$orphans pacote(s) sobrando: veja em Instalados (Ctrl+L limpa)."
        nothing=0
    fi
    if has_yay; then
        info "Os do AUR: aba AUR, em Atualizações."
    fi
    (( nothing )) && ok "Tudo certo."
}
