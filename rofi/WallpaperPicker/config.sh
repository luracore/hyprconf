#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/hyprconf/Wallpapers"
ROFI_THEME="$HOME/hyprconf/rofi/WallpaperPicker/config.rasi"
THUMB_DIR="$HOME/hyprconf/rofi/WallpaperPicker/thumbnails"
CURRENT_WALLPAPER=$(cat "$HOME/hyprconf/Wallpapers/current" 2>/dev/null)
CURRENT_NAME=$(basename "$CURRENT_WALLPAPER")

mkdir -p "$THUMB_DIR"

selected=$(
    while IFS= read -r file; do
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

        printf '%s\0icon\x1f%s\n' "$name" "$thumb"

    done < <(
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' \
               -o -iname '*.png' -o -iname '*.webp' \)
    ) | rofi -dmenu -show-icons -config "$ROFI_THEME" \
      -select "$CURRENT_NAME"
)

if [[ -n "$selected" && -f "$WALLPAPER_DIR/$selected" ]]; then
    printf '%s\n' "$WALLPAPER_DIR/$selected" > "$HOME/hyprconf/Wallpapers/current"
    ln -sfn "$WALLPAPER_DIR/$selected" "$HOME/hyprconf/Wallpapers/currentLink"

    awww img "$WALLPAPER_DIR/$selected" \
        --resize crop \
        --transition-type fade \
        --transition-duration 1
fi
