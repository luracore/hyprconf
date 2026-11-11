#!/usr/bin/env bash
# Lista os temas como "caminho<TAB>json compacto". Ignora o symlink "current"
# e arquivos com JSON inválido.

THEME_DIR="$HOME/hyprconf/Themes"

for file in "$THEME_DIR"/*.json; do
    [[ -f "$file" && ! -L "$file" ]] || continue

    json="$(jq -c . "$file" 2>/dev/null)" || continue

    printf '%s\t%s\n' "$file" "$json"
done
