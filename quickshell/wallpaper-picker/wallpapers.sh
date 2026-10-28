#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/hyprconf/Wallpapers"
THUMB_DIR="$HOME/hyprconf/Wallpapers/thumbnails"

mkdir -p "$THUMB_DIR"

find "$THUMB_DIR" -maxdepth 1 -type f -name '*.png' -print0 |
while IFS= read -r -d '' thumb; do
    name="$(basename "$thumb" .png)"
    wallpaper="$WALLPAPER_DIR/$name"

    if [[ ! -f "$wallpaper" ]]; then
        rm -f -- "$thumb"
    fi
done

find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' \
       -o -iname '*.png' -o -iname '*.webp' \) \
    -print0 |
while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    thumb="$THUMB_DIR/$name.png"

    if [[ ! -s "$thumb" || "$file" -nt "$thumb" ]]; then
        magick "$file" \
            -thumbnail '280x280^' \
            -gravity center \
            -extent 280x280 \
            "$thumb" || continue
    fi

    [[ -s "$thumb" ]] || continue

    printf '%s\t%s\n' "$file" "$thumb"
done
