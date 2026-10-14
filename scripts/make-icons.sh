#!/usr/bin/env bash
# Renders every icon, banner and splash screen the clients need from the Lanternfish wordmark.
# Needs ImageMagick and the Inter font. The results are committed, so this only runs when the artwork changes.
set -euo pipefail
cd "$(dirname "$0")/.."

FONT="${LANTERNFISH_FONT:-/usr/share/fonts/opentype/inter/Inter-Black.otf}"
# The Midnight theme's colors (shared/themes.json)
BG='#0D1117'
ACCENT='#7AA2FF'
GLOW='#DCE6FF'

# The lure: a lanternfish's glowing bulb on a curved stalk. Draws onto image $1 at (cx, cy) with bulb radius r.
lure() { # in cx cy r out
    local cx=$2 cy=$3 r=$4
    local sx=$(( cx - r * 4 )) sy=$(( cy + r * 5 ))
    convert "$1" \
        \( -size "$(identify -format '%wx%h' "$1")" xc:none -fill "$ACCENT" -draw "circle $cx,$cy $(( cx + r * 3 )),$cy" -blur "0x$(( r * 2 ))" \) -composite \
        -fill none -stroke "$ACCENT" -strokewidth "$(( r / 3 + 1 ))" -draw "path 'M $sx,$sy Q $(( cx - r * 4 )),$(( cy - r )) $(( cx - r )),$cy'" \
        -stroke none -fill "$ACCENT" -draw "circle $cx,$cy $(( cx + r )),$cy" \
        -fill "$GLOW" -draw "circle $(( cx - r / 3 )),$(( cy - r / 3 )) $(( cx )),$(( cy - r / 3 ))" \
        "$5"
}

# Square icon: the lure over a white "L" (on the background, or $CANVAS when set, e.g. none for transparent)
icon() { # size out
    local s=$1
    convert -size "${s}x${s}" "xc:${CANVAS:-$BG}" -font "$FONT" -fill white -gravity southwest \
        -pointsize "$(( s * 70 / 100 ))" -annotate "+$(( s * 14 / 100 ))+$(( s * 2 / 100 ))" 'L' "$2"
    lure "$2" $(( s * 70 / 100 )) $(( s * 27 / 100 )) $(( s * 8 / 100 + 1 )) "$2"
}

# Wide image: the wordmark, with the lure growing out of its "L" as on the icon
wide() { # width height out
    local w=$1 h=$2 p=$(( $1 / 8 ))
    local tw
    tw=$(convert -font "$FONT" -pointsize "$p" label:'Lanternfish' -format '%w' info:)
    local x0=$(( (w - tw) / 2 )) top=$(( h / 2 - p * 36 / 100 ))
    local r=$(( p / 11 + 1 ))
    convert -size "${w}x${h}" "xc:${CANVAS:-$BG}" -font "$FONT" -fill "${INK:-white}" -gravity west \
        -pointsize "$p" -annotate "+${x0}+0" 'Lanternfish' "$3"
    lure "$3" $(( x0 + p * 9 / 100 + r * 4 )) $(( top - r * 5 )) "$r" "$3"
}

mkdir -p webos tizen roku/images \
    android/app/src/main/res/{mipmap-mdpi,mipmap-hdpi,mipmap-xhdpi,mipmap-xxhdpi,mipmap-xxxhdpi,drawable-xhdpi}

icon 80 webos/icon.png
icon 130 webos/largeIcon.png
wide 1920 1080 webos/splash.png

icon 512 tizen/icon.png

icon 48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
icon 72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
icon 96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
icon 144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
icon 192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
# Android TV / Google TV launcher banner, and Fire TV's
wide 320 180 android/app/src/main/res/drawable-xhdpi/banner.png

# Roku channel posters (focus icons) and splash screens
wide 540 405 roku/images/channel-poster_fhd.png
wide 290 218 roku/images/channel-poster_hd.png
wide 1920 1080 roku/images/splash_fhd.png
wide 1280 720 roku/images/splash_hd.png
icon 336 roku/images/logo.png

# Roku: the fades that blend backdrops into the page, and the loading spinner. They're white; the app tints them with
# the theme's background and accent (Poster.blendColor)
convert -size 1080x1344 gradient:'#FFFFFFFF'-'#FFFFFF00' -rotate -90 PNG32:roku/images/fade-left.png
convert -size 1920x540 gradient:'#FFFFFF00'-'#FFFFFFFF' PNG32:roku/images/fade-bottom.png
convert -size 64x64 xc:none -fill none -stroke white -strokewidth 7 -draw "arc 6,6 58,58 0,270" PNG32:roku/images/spinner.png

# The JellyFlix web client's logos and browser icons, when WEB_ASSETS points at its src/assets/img/lanternfish folder
if [ -n "${WEB_ASSETS:-}" ]; then
    mkdir -p "$WEB_ASSETS"
    CANVAS=none icon 512 "$WEB_ASSETS/icon-transparent.png"
    CANVAS=none wide 1000 400 "$WEB_ASSETS/banner-light.png"
    CANVAS=none INK="$BG" wide 1000 400 "$WEB_ASSETS/banner-dark.png"
    for size in 72 114 144 512; do icon "$size" "$WEB_ASSETS/touchicon$size.png"; done
    icon 180 "$WEB_ASSETS/touchicon.png"
    icon 48 /tmp/lanternfish-favicon-48.png
    convert /tmp/lanternfish-favicon-48.png -define icon:auto-resize=48,32,16 "$WEB_ASSETS/favicon.ico"
    rm -f /tmp/lanternfish-favicon-48.png
fi
