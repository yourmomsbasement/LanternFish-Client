sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.title = m.top.findNode("title")
    m.seasonList = m.top.findNode("seasons")
    m.episodeList = m.top.findNode("episodes")
    m.spinner = m.top.findNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.debounce = m.top.findNode("debounce")
    m.focusTarget = m.seasonList
    m.seasons = []
    m.loadedSeason = ""

    m.seasonList.observeField("itemFocused", "onSeasonFocused")
    m.seasonList.observeField("itemSelected", "focusEpisodes")
    m.episodeList.observeField("itemSelected", "onEpisodeSelected")
    m.debounce.observeField("fire", "loadEpisodes")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "load")
    m.top.observeField("resumed", "onResumed")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusTarget.setFocus(true)
end sub

sub load()
    m.seriesId = m.top.params.seriesId
    m.startSeason = m.top.params.seasonId
    JF_Get("/Items/" + m.seriesId, { userId: m.global.userId }, "onSeries")
    JF_Get("/Shows/" + m.seriesId + "/Seasons", { userId: m.global.userId }, "onSeasons")
end sub

sub onSeries(event as Object)
    response = event.getRoSGNode().response
    if not response.ok or response.json = invalid then return
    m.title.text = response.json.Name
    m.backdrop.uri = JF_BackdropUrl(response.json)
end sub

sub onSeasons(event as Object)
    response = event.getRoSGNode().response
    if not response.ok or response.json = invalid or response.json.Items = invalid or response.json.Items.Count() = 0
        JF_ShowMessage("No episodes", "This show has no episodes in the library yet.")
        return
    end if
    m.seasons = response.json.Items
    content = CreateObject("roSGNode", "ContentNode")
    start = 0
    for i = 0 to m.seasons.Count() - 1
        season = m.seasons[i]
        node = content.createChild("ContentNode")
        node.title = season.Name
        if m.startSeason <> invalid and JF_NormalizeId(season.Id) = JF_NormalizeId(m.startSeason) then start = i
    end for
    m.seasonList.content = content
    m.seasonList.jumpToItem = start
    m.loadedSeason = ""
    m.pendingSeason = start
    loadEpisodes()
    ' Start on the episodes when the page was opened for a season
    if m.startSeason <> invalid then m.focusEpisodesWhenLoaded = true
end sub

sub onSeasonFocused()
    m.pendingSeason = m.seasonList.itemFocused
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub loadEpisodes()
    if m.pendingSeason = invalid or m.pendingSeason >= m.seasons.Count() then return
    season = m.seasons[m.pendingSeason]
    if season.Id = m.loadedSeason then return
    m.loadedSeason = season.Id
    m.spinner.visible = true
    m.spinner.control = "start"
    JF_Get("/Shows/" + m.seriesId + "/Episodes", { userId: m.global.userId, seasonId: season.Id, fields: "Overview" }, "onEpisodes", season.Id)
end sub

sub onResumed()
    ' Watched state and resume points changed while playing
    m.loadedSeason = ""
    loadEpisodes()
end sub

sub onEpisodes(event as Object)
    task = event.getRoSGNode()
    if task.tag <> m.loadedSeason then return
    m.spinner.control = "stop"
    m.spinner.visible = false
    response = task.response
    m.episodes = []
    if response.ok and response.json <> invalid and response.json.Items <> invalid then m.episodes = response.json.Items

    content = CreateObject("roSGNode", "ContentNode")
    firstUnwatched = -1
    for i = 0 to m.episodes.Count() - 1
        episode = m.episodes[i]
        node = content.createChild("ContentNode")
        number = ""
        if episode.IndexNumber <> invalid then number = episode.IndexNumber.ToStr() + ". "
        node.addFields({ episodeTitle: number + episode.Name, runtime: JF_Runtime(episode.RunTimeTicks), progress: JF_Progress(episode) })
        node.description = ""
        if episode.Overview <> invalid then node.description = episode.Overview
        node.HDPosterUrl = JF_ThumbUrl(episode, 320)
        if firstUnwatched < 0 and not JF_IsPlayed(episode) then firstUnwatched = i
    end for
    focused = m.episodeList.itemFocused
    m.episodeList.content = content
    if m.focusEpisodesWhenLoaded = true
        m.focusEpisodesWhenLoaded = false
        if firstUnwatched >= 0 then m.episodeList.jumpToItem = firstUnwatched
        focusEpisodes()
    else if focused > 0 and focused < m.episodes.Count()
        m.episodeList.jumpToItem = focused
    end if
end sub

sub focusEpisodes()
    if m.episodeList.content = invalid or m.episodeList.content.getChildCount() = 0 then return
    m.focusTarget = m.episodeList
    m.episodeList.setFocus(true)
end sub

sub onEpisodeSelected()
    episode = m.episodes[m.episodeList.itemSelected]
    m.top.navigate = { screen: "PlayerScreen", params: { itemId: episode.Id } }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "right" and m.seasonList.hasFocus()
        focusEpisodes()
        return true
    else if (key = "left" or key = "back") and m.episodeList.hasFocus()
        m.focusTarget = m.seasonList
        m.seasonList.setFocus(true)
        return true
    else if key = "play" and m.episodeList.hasFocus()
        onEpisodeSelectedAt(m.episodeList.itemFocused)
        return true
    end if
    return false
end function

sub onEpisodeSelectedAt(index as Integer)
    if index < 0 or index >= m.episodes.Count() then return
    m.top.navigate = { screen: "PlayerScreen", params: { itemId: m.episodes[index].Id } }
end sub
