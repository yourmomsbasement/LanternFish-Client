#!/usr/bin/env bash
# Renders every icon, banner and splash screen the clients need from the JellyFlix wordmark.
# Needs ImageMagick and the Inter font. The results are committed, so this only runs when the artwork changes.
set -euo pipefail
cd "$(dirname "$0")/.."

FONT="${JELLYFLIX_FONT:-/usr/share/fonts/opentype/inter/Inter-Black.otf}"
BG='#141414'
RED='#e50914'

# Square icon: a red "J" (+ "F") monogram
icon() { # size out
    convert -size "$1x$1" "xc:$BG" -font "$FONT" -fill "$RED" -gravity center \
        -pointsize "$(( $1 * 62 / 100 ))" -annotate +0+0 'JF' "$2"
}
# Wide image: the wordmark centered with a red glow at the bottom
wide() { # width height out
    local w=$1 h=$2
    convert -size "${w}x${h}" "radial-gradient:#3a0508-$BG" -gravity south -crop "${w}x${h}+0+0" +repage \
        \( -size "${w}x${h}" "xc:$BG" \) -compose blend -define compose:args=60 -composite \
        -font "$FONT" -fill "$RED" -gravity center -pointsize "$(( w / 7 ))" -annotate +0+0 'JELLYFLIX' -depth 8 -colors 128 "$3"
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

# Roku: the fades that blend backdrops into the page, and the loading spinner
convert -size 1080x1344 gradient:"${BG}FF"-"${BG}00" -rotate -90 PNG32:roku/images/fade-left.png
convert -size 1920x540 gradient:"${BG}00"-"${BG}FF" PNG32:roku/images/fade-bottom.png
convert -size 1920x300 gradient:'#000000CC'-'#00000000' PNG32:roku/images/fade-top.png
convert -size 64x64 xc:none -fill none -stroke "$RED" -strokewidth 7 -draw "arc 6,6 58,58 0,270" PNG32:roku/images/spinner.png
