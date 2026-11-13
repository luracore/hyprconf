#!/usr/bin/env bash
# Lista os wallpapers como "caminho<TAB>miniatura", gerando miniaturas 16:9
# (960x540, jpg) em Wallpapers/thumbnails quando faltam ou estão velhas.

WALLPAPER_DIR="$HOME/hyprconf/Wallpapers"
THUMB_DIR="$WALLPAPER_DIR/thumbnails"

mkdir -p "$THUMB_DIR"

# Remove miniaturas órfãs e as do formato antigo (quadradas, *.png).
find "$THUMB_DIR" -maxdepth 1 -type f -print0 |
while IFS= read -r -d '' thumb; do
    file="$(basename "$thumb")"

    if [[ "$file" != *.jpg || ! -f "$WALLPAPER_DIR/${file%.jpg}" ]]; then
        rm -f -- "$thumb"
    fi
done

find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' \
       -o -iname '*.png' -o -iname '*.webp' \) \
    -print0 | sort -z |
while IFS= read -r -d '' file; do
    thumb="$THUMB_DIR/$(basename "$file").jpg"

    if [[ ! -s "$thumb" || "$file" -nt "$thumb" ]]; then
        magick -quiet "$file" \
            -thumbnail '960x540^' \
            -gravity center \
            -extent 960x540 \
            -quality 88 \
            "$thumb" || continue
    fi

    [[ -s "$thumb" ]] || continue

    printf '%s\t%s\n' "$file" "$thumb"
done
