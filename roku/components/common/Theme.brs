' Color themes. Components are written in the base palette (see shared/themes.json); JF_ApplyTheme swaps those colors
' for the chosen theme's when a component starts. Include with Themes.brs (the generated table):
'   <script type="text/brightscript" uri="pkg:/components/common/Theme.brs" />
'   <script type="text/brightscript" uri="pkg:/components/common/Themes.brs" />

' The theme for the signed-in profile (each profile picks its own), else the device's, else the default
function JF_FindTheme(id as Dynamic) as Dynamic
    if id = invalid or id = "" then return invalid
    for each theme in JF_ThemeList()
        if theme.id = id then return theme
    end for
    return invalid
end function

function JF_ThemeKey(userId as Dynamic) as String
    if userId = invalid or userId = "" then return "theme"
    return "theme-" + userId
end function

' Loads the theme for [userId] into m.global.theme (MainScene observes it)
sub JF_LoadTheme(userId as Dynamic)
    section = CreateObject("roRegistrySection", "lanternfish")
    theme = invalid
    for each key in [JF_ThemeKey(userId), JF_ThemeKey(invalid)]
        if theme = invalid and section.Exists(key) then theme = JF_FindTheme(section.Read(key))
    end for
    if theme = invalid then theme = JF_FindTheme(JF_DefaultThemeId())
    m.global.theme = theme
end sub

' Chooses theme [id] for [userId], and for the device as the default for new profiles
sub JF_SaveTheme(userId as Dynamic, id as String)
    section = CreateObject("roRegistrySection", "lanternfish")
    section.Write(JF_ThemeKey(userId), id)
    section.Write(JF_ThemeKey(invalid), id)
    section.Flush()
    JF_LoadTheme(userId)
end sub

' A color of the current theme, e.g. JF_Color("accent") -> "0x7AA2FFFF"
function JF_Color(token as String) as String
    theme = m.global.theme
    if theme = invalid or theme.colors = invalid then theme = JF_FindTheme(JF_DefaultThemeId())
    color = theme.colors[token]
    if color = invalid then return "0xFFFFFFFF"
    return color
end function

' ---- Recoloring components -----------------------------------------------------------------------------------------

' Fields that hold colors on the nodes Lanternfish uses
function JF_ColorFields() as Object
    return ["color", "focusedColor", "rowLabelColor", "focusBitmapBlendColor", "blendColor"]
end function

' "RRGGBB" and "AA" of a color field value, which reads back as a "0xRRGGBBAA" string or a 32-bit integer
function JF_ColorParts(value as Dynamic) as Dynamic
    if value = invalid then return invalid
    if GetInterface(value, "ifString") <> invalid
        text = UCase(value)
        if Left(text, 2) = "0X" then text = Mid(text, 3)
        if Left(text, 1) = "#" then text = Mid(text, 2)
        if Len(text) = 6 then text = text + "FF"
        if Len(text) <> 8 then return invalid
        return { rgb: Left(text, 6), alpha: Right(text, 2) }
    end if
    if GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifLongInt") <> invalid
        rgbValue = (value >> 8) and &hFFFFFF
        alphaValue = value and &hFF
        return { rgb: JF_Hex(rgbValue, 6), alpha: JF_Hex(alphaValue, 2) }
    end if
    return invalid
end function

function JF_Hex(value as Integer, digits as Integer) as String
    text = UCase(StrI(value, 16))
    while Len(text) < digits
        text = "0" + text
    end while
    return text
end function

' The theme's version of a base-palette color, keeping its transparency; invalid when it isn't a themed color
function JF_ThemedColor(value as Dynamic, tokens as Object, colors as Object) as Dynamic
    parts = JF_ColorParts(value)
    if parts = invalid then return invalid
    token = tokens[parts.rgb]
    if token = invalid or colors[token] = invalid then return invalid
    return Left(colors[token], 8) + parts.alpha
end function

' Recolors [node] and everything under it from the base palette to the current theme
sub JF_ApplyTheme(node as Object)
    theme = m.global.theme
    if theme = invalid or theme.colors = invalid then return
    JF_RecolorNode(node, JF_BaseColorTokens(), theme.colors, JF_ColorFields())
end sub

sub JF_RecolorNode(node as Object, tokens as Object, colors as Object, fields as Object)
    for each field in fields
        if node.hasField(field)
            themed = JF_ThemedColor(node.getField(field), tokens, colors)
            if themed <> invalid then node.setField(field, themed)
        end if
    end for
    for i = 0 to node.getChildCount() - 1
        JF_RecolorNode(node.getChild(i), tokens, colors, fields)
    end for
end sub

' BusySpinners: the white spinner image, tinted with the accent
sub JF_StyleSpinner(spinner as Object)
    spinner.poster.uri = "pkg:/images/spinner.png"
    spinner.poster.blendColor = JF_Color("accent")
end sub

' Standard dialogs (keyboards, PIN pad, messages) in the theme's colors
function JF_DialogPalette() as Object
    palette = CreateObject("roSGNode", "RSGPalette")
    palette.colors = {
        DialogBackgroundColor: JF_Color("surface"),
        DialogItemColor: "0xFFFFFFFF",
        DialogTextColor: "0xFFFFFFFF",
        DialogFocusColor: "0xFFFFFFFF",
        DialogFocusItemColor: JF_Color("background"),
        DialogSecondaryTextColor: JF_Color("muted"),
        DialogSecondaryItemColor: JF_Color("accent"),
        DialogInputFieldColor: JF_Color("highlight"),
        DialogKeyboardColor: JF_Color("highlight"),
        DialogFootprintColor: JF_Color("muted")
    }
    return palette
end function
