' Tests for the theme runtime (components/common/Theme.brs). Run with `npm run test:roku`.

sub Main()
    m.global = { theme: JF_FindTheme("midnight") }
    tokens = JF_BaseColorTokens()
    colors = m.global.theme.colors

    check("default theme exists", JF_FindTheme(JF_DefaultThemeId()) <> invalid, true)
    check("default isn't the red one", JF_DefaultThemeId() <> "classic", true)
    check("unknown theme", JF_FindTheme("nope") = invalid, true)
    check("classic red is offered", JF_FindTheme("classic").name, "Classic Red")

    ' Colors read back as strings
    check("string parts", FormatJson(JF_ColorParts("0xe50914ff")), FormatJson({ alpha: "FF", rgb: "E50914" }))
    check("short string parts", FormatJson(JF_ColorParts("#141414")), FormatJson({ alpha: "FF", rgb: "141414" }))
    ' ... or as signed 32-bit integers
    check("integer parts", FormatJson(JF_ColorParts(&hE50914FF)), FormatJson({ alpha: "FF", rgb: "E50914" }))
    check("integer with alpha", FormatJson(JF_ColorParts(&h141414F0)), FormatJson({ alpha: "F0", rgb: "141414" }))
    check("small integer", FormatJson(JF_ColorParts(&h000A0B0C)), FormatJson({ alpha: "0C", rgb: "000A0B" }))

    check("accent swapped", JF_ThemedColor("0xE50914FF", tokens, colors), "0x7AA2FFFF")
    check("integer accent swapped", JF_ThemedColor(&hE50914FF, tokens, colors), "0x7AA2FFFF")
    check("transparency kept", JF_ThemedColor("0x141414F0", tokens, colors), "0x0D1117F0")
    check("white untouched", JF_ThemedColor("0xFFFFFFFF", tokens, colors) = invalid, true)
    check("black untouched", JF_ThemedColor("0x000000FF", tokens, colors) = invalid, true)
    check("color lookup", JF_Color("accent"), "0x7AA2FFFF")

    m.global.theme = JF_FindTheme("classic")
    check("classic is the base palette", JF_ThemedColor("0xE50914FF", tokens, m.global.theme.colors), "0xE50914FF")
end sub

sub check(name as String, actual as Dynamic, expected as Dynamic)
    if actual = expected
        print "PASS " + name
    else
        print "FAIL " + name + ": expected [" + FormatJson(expected) + "] got [" + FormatJson(actual) + "]"
    end if
end sub
