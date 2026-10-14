' Tests for the pure helpers, run with `npm run test:roku` (the @rokucommunity/brs interpreter; no device needed).
' Each test prints PASS or FAIL; the runner fails when any FAIL is printed.

sub Main()
    m.global = { server: "http://nas:8096", artwork: {} }

    check("runtime minutes", JF_Runtime(27000000000), "45m")
    check("runtime hours", JF_Runtime(72600000000&), "2h 1m")
    check("runtime whole hours", JF_Runtime(36000000000&), "1h")
    check("runtime none", JF_Runtime(invalid), "")

    check("hex color", JF_HexColor("#e50914"), "0xE50914FF")
    check("short hex color", JF_HexColor("#0af"), "0x00AAFFFF")
    check("bad hex color", JF_HexColor("red"), "0xE50914FF")

    check("join", JF_Join(["2019", "PG-13", "2h 1m"], " · "), "2019 · PG-13 · 2h 1m")
    check("meta movie", JF_MetaLine({ Type: "Movie", ProductionYear: 2019, OfficialRating: "PG-13", RunTimeTicks: 72600000000& }), "2019  ·  PG-13  ·  2h 1m")
    check("meta series", JF_MetaLine({ Type: "Series", ProductionYear: 2008, ChildCount: 5 }), "2008  ·  5 Seasons")

    check("episode code", JF_EpisodeCode({ ParentIndexNumber: 2, IndexNumber: 5 }), "S2:E5")
    check("progress", Str(JF_Progress({ UserData: { PlayedPercentage: 50 } })).Trim(), "0.5")
    check("played", JF_IsPlayed({ UserData: { Played: true } }), true)
    check("not played", JF_IsPlayed({}), false)

    check("ticks", JF_SecondsToTicks(7000.5).ToStr(), "70005000000")
    check("ticks zero", JF_SecondsToTicks(invalid).ToStr(), "0")

    check("normalize id", JF_NormalizeId("AB-CD"), "abcd")
    check("poster url", JF_PosterUrl({ Id: "m1", Type: "Movie", ImageTags: { Primary: "t1" } }), "http://nas:8096/Items/m1/Images/Primary?quality=90&fillHeight=450&tag=t1")
    check("episode poster is the show's", JF_PosterUrl({ Id: "e1", Type: "Episode", SeriesId: "s1", SeriesPrimaryImageTag: "st" }), "http://nas:8096/Items/s1/Images/Primary?quality=90&fillHeight=450&tag=st")
    m.global.artwork = { "m1": { Poster: "JellyFlix/Artwork/Images/abc.jpg" } }
    check("artwork override", JF_PosterUrl({ Id: "M1", Type: "Movie", ImageTags: { Primary: "t1" } }), "http://nas:8096/JellyFlix/Artwork/Images/abc.jpg?fillHeight=450")
    m.global.artwork = {}

    check("candidates bare host", JF_Join(serverCandidates("nas"), " "), "http://nas http://nas:8096")
    check("candidates with port", JF_Join(serverCandidates(" 192.168.1.10:8096/ "), " "), "http://192.168.1.10:8096")
    check("candidates https path", JF_Join(serverCandidates("https://media.example.com/jellyfin/"), " "), "https://media.example.com/jellyfin")
    check("candidates web url", JF_Join(serverCandidates("http://nas:8096/web/index.html"), " "), "http://nas:8096")
    check("candidates empty", serverCandidates("http://").Count(), 0)
end sub

sub check(name as String, actual as Dynamic, expected as Dynamic)
    if actual = expected
        print "PASS " + name
    else
        print "FAIL " + name + ": expected [" + FormatJson(expected) + "] got [" + FormatJson(actual) + "]"
    end if
end sub
