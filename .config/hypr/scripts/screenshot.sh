#!/usr/bin/env bash

set -euo pipefail

SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/screenshot"
mkdir -p "$SCREENSHOT_DIR"

timestamp() {
    date +%Y%m%d_%H%M%S
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a screenshot "$@"
    fi
}

slurp_region() {
    slurp \
        -b 1e1e2ecc \
        -c cba6f7ff \
        -s f5c2e755 \
        -B 181825dd \
        -w 2
}

copy_image() {
    local file="$1"
    local targets=()

    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy --type image/png < "$file"
        targets+=("Wayland")
    fi

    if command -v xclip >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        xclip -selection clipboard -target image/png -i "$file"
        targets+=("X11")
    fi

    if [ "${#targets[@]}" -eq 0 ]; then
        notify "Screenshot copy failed" "No clipboard tool found"
        return 1
    fi

    notify "Screenshot copied" "$(basename "$file") -> ${targets[*]}"
}

capture_region() {
    local file="$1"
    local geometry

    geometry="$(slurp_region)" || exit 0
    [ -n "$geometry" ] || exit 0
    grim -g "$geometry" "$file"
}

capture_full() {
    local file="$1"

    grim "$file"
}

region_copy() {
    local file

    file="$(mktemp --suffix=.png)"
    capture_region "$file"
    copy_image "$file"
    rm -f "$file"
}

region_save() {
    local file="$SCREENSHOT_DIR/snip_$(timestamp).png"

    capture_region "$file"
    notify "Screenshot saved" "$file"
}

region_save_copy() {
    local file="$SCREENSHOT_DIR/snip_$(timestamp).png"

    capture_region "$file"
    copy_image "$file"
    notify "Screenshot saved" "$file"
}

full_save_copy() {
    local file="$SCREENSHOT_DIR/screen_$(timestamp).png"

    capture_full "$file"
    copy_image "$file"
    notify "Screenshot saved" "$file"
}

full_copy() {
    local file

    file="$(mktemp --suffix=.png)"
    capture_full "$file"
    copy_image "$file"
    rm -f "$file"
}

annotate_region() {
    local raw output action

    raw="$(mktemp --suffix=.png)"
    output="$SCREENSHOT_DIR/marked_$(timestamp).png"

    capture_region "$raw"
    swappy -f "$raw" -o "$output"
    rm -f "$raw"

    [ -s "$output" ] || exit 0

    action="$(
        printf '%s\n' "Save + copy" "Save only" "Copy only" "Discard" |
            rofi -dmenu -p "Annotated screenshot"
    )" || exit 0

    case "$action" in
        "Save + copy")
            copy_image "$output"
            notify "Annotated screenshot saved" "$output"
            ;;
        "Save only")
            notify "Annotated screenshot saved" "$output"
            ;;
        "Copy only")
            copy_image "$output"
            rm -f "$output"
            ;;
        "Discard")
            rm -f "$output"
            ;;
    esac
}

menu() {
    local choice

    choice="$(
        printf '%s\n' \
            "Quick snip -> copy" \
            "Snip -> save" \
            "Snip -> save + copy" \
            "Snip -> highlight / annotate" \
            "Full screen -> copy" \
            "Full screen -> save + copy" |
            rofi -dmenu -p "Screenshot"
    )" || exit 0

    case "$choice" in
        "Quick snip -> copy") region_copy ;;
        "Snip -> save") region_save ;;
        "Snip -> save + copy") region_save_copy ;;
        "Snip -> highlight / annotate") annotate_region ;;
        "Full screen -> copy") full_copy ;;
        "Full screen -> save + copy") full_save_copy ;;
    esac
}

case "${1:-menu}" in
    menu) menu ;;
    region-copy) region_copy ;;
    region-save) region_save ;;
    region-save-copy) region_save_copy ;;
    full-copy) full_copy ;;
    full-save-copy) full_save_copy ;;
    annotate) annotate_region ;;
    *)
        printf 'Usage: %s [menu|region-copy|region-save|region-save-copy|full-copy|full-save-copy|annotate]\n' "$0" >&2
        exit 2
        ;;
esac
