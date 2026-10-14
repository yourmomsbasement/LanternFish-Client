sub init()
    m.page = m.top.findNode("page")
    m.hero = m.top.findNode("hero")
    m.extras = m.top.findNode("extras")
    m.buttons = m.top.findNode("buttons")
    m.similar = m.top.findNode("similar")
    m.spinner = m.top.findNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.focusTarget = m.buttons
    m.actions = []

    m.buttons.observeField("itemSelected", "onButton")
    m.similar.observeField("rowItemSelected", "onSimilarSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "load")
    m.top.observeField("resumed", "onResumed")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusTarget.setFocus(true)
end sub

sub load()
    m.itemId = m.top.params.itemId
    m.spinner.visible = true
    m.spinner.control = "start"
    JF_Get("/Items/" + m.itemId, { userId: m.global.userId }, "onItem")
    JF_Get("/JellyFlix/Recommendations/Similar/" + m.itemId, invalid, "onSimilar", "jellyflix")
end sub

' Coming back from the player: the resume point and next episode have moved
sub onResumed()
    JF_Get("/Items/" + m.itemId, { userId: m.global.userId }, "onItem")
end sub

sub onItem(event as Object)
    m.spinner.control = "stop"
    m.spinner.visible = false
    response = event.getRoSGNode().response
    if not response.ok or response.json = invalid
        JF_ShowMessage("Couldn't open this title", response.error)
        return
    end if
    m.item = response.json
    item = m.item

    node = JF_ItemNode(item)
    if item.Type = "Episode" then node.subtitle = JF_EpisodeCode(item) + "  " + item.Name
    m.hero.content = node

    extras = []
    cast = JF_People(item, "Actor", 4)
    if cast <> "" then extras.Push("Starring: " + cast)
    if item.Genres <> invalid and item.Genres.Count() > 0 then extras.Push("Genres: " + JF_Join(item.Genres, ", "))
    m.extras.text = JF_Join(extras, Chr(10))

    if item.Type = "Series"
        ' Play picks up the right episode: the next one up, or the first
        JF_Get("/Shows/NextUp", { userId: m.global.userId, seriesId: item.Id, limit: 1, enableImages: false }, "onNextUp")
    else
        m.playTarget = item
        renderButtons()
    end if
end sub

sub onNextUp(event as Object)
    response = event.getRoSGNode().response
    items = invalid
    if response.ok and response.json <> invalid then items = response.json.Items
    if items <> invalid and items.Count() > 0
        m.playTarget = items[0]
        renderButtons()
    else
        JF_Get("/Shows/" + m.item.Id + "/Episodes", { userId: m.global.userId, limit: 1 }, "onFirstEpisode")
    end if
end sub

sub onFirstEpisode(event as Object)
    response = event.getRoSGNode().response
    m.playTarget = invalid
    if response.ok and response.json <> invalid and response.json.Items <> invalid and response.json.Items.Count() > 0
        m.playTarget = response.json.Items[0]
    end if
    renderButtons()
end sub

function resumeTicks(item as Dynamic) as Dynamic
    if item = invalid or item.UserData = invalid or item.UserData.PlaybackPositionTicks = invalid then return 0
    return item.UserData.PlaybackPositionTicks
end function

sub renderButtons()
    m.actions = []
    target = m.playTarget
    if target <> invalid
        label = "Play"
        position = resumeTicks(target)
        if position > 0 then label = "Resume"
        if target.Type = "Episode" and m.item.Type = "Series" then label = label + " " + JF_EpisodeCode(target)
        if position > 0 and target.RunTimeTicks <> invalid
            remaining = JF_Runtime(target.RunTimeTicks - position)
            if remaining <> "" then label = label + "  (" + remaining + " left)"
        end if
        m.actions.Push({ id: "play", title: label })
        if position > 0 then m.actions.Push({ id: "restart", title: "Play from the beginning" })
    end if
    if m.item.Type = "Series" or m.item.Type = "Season" or m.item.Type = "Episode"
        m.actions.Push({ id: "episodes", title: "Episodes" })
    end if
    if m.item.Type <> "Episode" then m.actions.Push({ id: "mylist", title: myListTitle() })

    content = CreateObject("roSGNode", "ContentNode")
    for each action in m.actions
        node = content.createChild("ContentNode")
        node.title = action.title
    end for
    focused = m.buttons.itemFocused
    m.buttons.content = content
    if focused > 0 and focused < m.actions.Count() then m.buttons.jumpToItem = focused
    if m.focusTarget.isSameNode(m.buttons) and m.top.isInFocusChain() then m.buttons.setFocus(true)
end sub

function isFavorite() as Boolean
    return m.item.UserData <> invalid and JF_IsTrue(m.item.UserData.IsFavorite)
end function

function myListTitle() as String
    if isFavorite() then return "✓  In My List"
    return "+  My List"
end function

sub onButton()
    action = m.actions[m.buttons.itemSelected]
    if action.id = "play"
        m.top.navigate = { screen: "PlayerScreen", params: { itemId: m.playTarget.Id } }
    else if action.id = "restart"
        m.top.navigate = { screen: "PlayerScreen", params: { itemId: m.playTarget.Id, fromBeginning: true } }
    else if action.id = "episodes"
        seriesId = m.item.Id
        if m.item.SeriesId <> invalid then seriesId = m.item.SeriesId
        seasonId = invalid
        if m.playTarget <> invalid then seasonId = m.playTarget.SeasonId
        if m.item.Type = "Season" then seasonId = m.item.Id
        m.top.navigate = { screen: "EpisodesScreen", params: { seriesId: seriesId, seasonId: seasonId } }
    else if action.id = "mylist"
        method = "POST"
        if isFavorite() then method = "DELETE"
        JF_Request(method, "/UserFavoriteItems/" + m.item.Id, { userId: m.global.userId }, invalid, "onFavoriteChanged")
    end if
end sub

sub onFavoriteChanged(event as Object)
    response = event.getRoSGNode().response
    if not response.ok
        JF_ShowMessage("Couldn't change My List", response.error)
        return
    end if
    if m.item.UserData = invalid then m.item.UserData = {}
    if response.json <> invalid and response.json.IsFavorite <> invalid
        m.item.UserData.IsFavorite = response.json.IsFavorite
    else
        m.item.UserData.IsFavorite = not isFavorite()
    end if
    renderButtons()
end sub

' ---- More Like This -------------------------------------------------------------------------------------------------

sub onSimilar(event as Object)
    task = event.getRoSGNode()
    response = task.response
    items = invalid
    if response.ok and response.json <> invalid
        items = response.json.Items
        if task.tag = "jellyflix" and response.json.Match <> invalid then m.hero.match = response.json.Match
    end if
    if (items = invalid or items.Count() = 0) and task.tag = "jellyflix"
        ' No JellyFlix plugin: Jellyfin's own similar titles
        JF_Get("/Items/" + m.itemId + "/Similar", { userId: m.global.userId, limit: 16, fields: JF_ItemFields() }, "onSimilar", "jellyfin")
        return
    end if
    row = JF_RowNode("More Like This", items)
    if row = invalid then return
    content = CreateObject("roSGNode", "ContentNode")
    content.appendChild(row)
    m.similar.content = content
end sub

sub onSimilarSelected()
    focus = m.similar.rowItemFocused
    node = m.similar.content.getChild(focus[0]).getChild(focus[1])
    m.top.navigate = { screen: "DetailsScreen", params: { itemId: node.itemId } }
end sub

sub scrollPage(y as Integer)
    m.scrollTo.keyValue = [m.page.translation, [0, y]]
    m.scroll.control = "start"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "down" and m.buttons.hasFocus() and m.similar.content <> invalid
        m.focusTarget = m.similar
        m.similar.setFocus(true)
        scrollPage(-540)
        return true
    else if (key = "up" or key = "back") and m.similar.isInFocusChain()
        m.focusTarget = m.buttons
        m.buttons.setFocus(true)
        scrollPage(0)
        return true
    else if key = "play" and m.playTarget <> invalid
        m.top.navigate = { screen: "PlayerScreen", params: { itemId: m.playTarget.Id } }
        return true
    end if
    return false
end function
