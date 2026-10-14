' Generated from shared/themes.json by scripts/gen-themes.mjs. Edit that file, then run `npm run themes`.

function JF_ThemeList() as Object
    return [
        { id: "midnight", name: "Midnight", colors: { background: "0x0D1117FF", surface: "0x1C2230FF", highlight: "0x2A3242FF", track: "0x4A5468FF", accent: "0x7AA2FFFF", heading: "0xE3E8F2FF", textSecondary: "0xD3D8E2FF", muted: "0xA9B1C2FF", faint: "0x7F889AFF", match: "0x4CD9A0FF" } },
        { id: "ember", name: "Ember", colors: { background: "0x14100EFF", surface: "0x2A211CFF", highlight: "0x3A2E27FF", track: "0x5E4C40FF", accent: "0xFF8A3DFF", heading: "0xF2E8E2FF", textSecondary: "0xE2D6CFFF", muted: "0xBBADA4FF", faint: "0x8D8077FF", match: "0x9BD96BFF" } },
        { id: "aurora", name: "Aurora", colors: { background: "0x0A1413FF", surface: "0x16282AFF", highlight: "0x21383AFF", track: "0x3F5E5EFF", accent: "0x2ED3B7FF", heading: "0xE0F0EEFF", textSecondary: "0xCFE3E0FF", muted: "0xA1BAB7FF", faint: "0x74908CFF", match: "0xB7E36BFF" } },
        { id: "classic", name: "Classic Red", colors: { background: "0x141414FF", surface: "0x2A2A2AFF", highlight: "0x333333FF", track: "0x5A5A5AFF", accent: "0xE50914FF", heading: "0xE5E5E5FF", textSecondary: "0xD0D0D0FF", muted: "0xB3B3B3FF", faint: "0x808080FF", match: "0x46D369FF" } }
    ]
end function

function JF_DefaultThemeId() as String
    return "midnight"
end function

' The colors the XML is written in (the "classic" theme), by RGB, and the token each stands for
function JF_BaseColorTokens() as Object
    return {
        "141414": "background",
        "2A2A2A": "surface",
        "333333": "highlight",
        "5A5A5A": "track",
        "E50914": "accent",
        "E5E5E5": "heading",
        "D0D0D0": "textSecondary",
        "B3B3B3": "muted",
        "808080": "faint",
        "46D369": "match"
    }
end function
