' Rows, in order: [tag, title]. "Because you watched" rows go before Top Rated.
function homeRows() as Object
    return [
        ["resume", "Continue Watching"],
        ["nextup", "Next Up"],
        ["toppicks", "Top Picks"],
        ["mylist", "My List"],
        ["latest", "New on Lanternfish"],
        ["because", ""],
        ["toprated", "Top Rated"]
    ]
end function

sub init()
    JF_ApplyTheme(m.top)
    m.hero = m.top.findNode("hero")
    m.rows = m.top.findNode("rows")
    m.menu = m.top.findNode("menu")
    m.spinner = m.top.findNode("spinner")
    JF_StyleSpinner(m.spinner)
    m.empty = m.top.findNode("empty")
    m.focusTarget = m.rows
    m.results = {}
    m.pending = 0
    m.profileName = ""

    m.rows.observeField("rowItemFocused", "onItemFocused")
    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.menu.observeField("selected", "onMenu")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "load")
    m.top.observeField("resumed", "onResumed")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusTarget.setFocus(true)
end sub

' ---- Loading --------------------------------------------------------------------------------------------------------

sub load()
    m.spinner.visible = true
    m.spinner.control = "start"
    m.results = {}
    userId = m.global.userId
    fields = JF_ItemFields()
    images = "Primary,Backdrop,Logo,Thumb"
    library = { userId: userId, recursive: true, includeItemTypes: "Movie,Series", fields: fields, enableImageTypes: images, imageTypeLimit: 1, limit: 30 }

    requests = [
        ["artwork", "/JellyFlix/Artwork", invalid],
        ["household", "/JellyFlix/Profiles", invalid],
        ["toppicks", "/JellyFlix/Recommendations", invalid],
        ["resume", "/UserItems/Resume", { userId: userId, limit: 20, mediaTypes: "Video", fields: fields, enableImageTypes: images, imageTypeLimit: 1 }],
        ["nextup", "/Shows/NextUp", { userId: userId, limit: 20, fields: fields, enableImageTypes: images, imageTypeLimit: 1 }],
        ["mylist", "/Items", withQuery(library, { filters: "IsFavorite", sortBy: "DateCreated", sortOrder: "Descending" })],
        ["latest", "/Items", withQuery(library, { sortBy: "DateCreated", sortOrder: "Descending" })],
        ["toprated", "/Items", withQuery(library, { sortBy: "CommunityRating", sortOrder: "Descending", minCommunityRating: 7, filters: "IsUnplayed" })]
    ]
    m.pending = requests.Count()
    for each request in requests
        JF_Get(request[1], request[2], "onRowLoaded", request[0])
    end for
end sub

function withQuery(base as Object, extra as Object) as Object
    query = {}
    query.Append(base)
    query.Append(extra)
    return query
end function

sub onRowLoaded(event as Object)
    task = event.getRoSGNode()
    response = task.response
    if response.code = 401
        JF_ClearSession()
        m.top.navigate = { screen: "LoginScreen", reset: true }
        return
    end if
    if response.ok then m.results[task.tag] = response.json
    m.pending = m.pending - 1
    ' Build the rows once, when everything is in: rebuilding them would move the focus under the user
    if m.pending = 0 then render()
end sub

function itemsOf(json as Dynamic) as Dynamic
    if json = invalid then return invalid
    if json.Items <> invalid then return json.Items
    return invalid
end function

sub render()
    m.spinner.control = "stop"
    m.spinner.visible = false

    ' The profile's own posters and backgrounds, before any poster URL is made
    artwork = m.results.artwork
    if artwork = invalid then artwork = {}
    normalized = {}
    for each key in artwork
        normalized[JF_NormalizeId(key)] = artwork[key]
    end for
    m.global.artwork = normalized

    household = m.results.household
    if household <> invalid and household.Profiles <> invalid
        for each profile in household.Profiles
            if JF_NormalizeId(profile.Id) = JF_NormalizeId(household.CurrentProfileId) then m.profileName = profile.Name
        end for
    end if
    m.menu.profileName = m.profileName

    recommendations = m.results.toppicks
    m.matches = {}
    content = CreateObject("roSGNode", "ContentNode")
    m.rowTags = []
    resumeSeries = {}

    for each row in homeRows()
        tag = row[0]
        title = row[1]
        if tag = "toppicks"
            if recommendations <> invalid and recommendations.Recommended <> invalid
                picks = []
                for each pick in recommendations.Recommended
                    picks.Push(pick.Item)
                end for
                if m.profileName <> "" then title = "Top Picks for " + m.profileName
                addRow(content, tag, title, picks)
            end if
        else if tag = "because"
            if recommendations <> invalid and recommendations.BecauseYouWatched <> invalid
                for each seed in recommendations.BecauseYouWatched
                    addRow(content, tag, "Because you watched " + seed.SeedName, seed.Items)
                end for
            end if
        else
            items = itemsOf(m.results[tag])
            if tag = "resume" and items <> invalid
                for each item in items
                    if item.SeriesId <> invalid then resumeSeries[item.SeriesId] = true
                end for
            else if tag = "nextup" and items <> invalid
                ' Shows already in Continue Watching don't need a second card
                filtered = []
                for each item in items
                    if item.SeriesId = invalid or resumeSeries[item.SeriesId] = invalid then filtered.Push(item)
                end for
                items = filtered
            end if
            addRow(content, tag, title, items)
        end if
    end for

    if content.getChildCount() = 0
        m.empty.text = "Nothing to show yet. Add movies and shows to your Jellyfin libraries, or check this profile's library access."
        m.empty.visible = true
        m.focusTarget = m.top
        return
    end if
    m.empty.visible = false

    restore = m.restoreFocus
    m.rows.content = content
    if restore <> invalid and restore[0] < content.getChildCount()
        row = content.getChild(restore[0])
        column = restore[1]
        if column >= row.getChildCount() then column = row.getChildCount() - 1
        m.rows.jumpToRowItem = [restore[0], column]
    end if
    m.restoreFocus = invalid
    m.focusTarget = m.rows
    if m.top.isInFocusChain() or m.top.hasFocus() then m.rows.setFocus(true)
    showHero(content.getChild(0).getChild(0))
end sub

sub addRow(content as Object, tag as String, title as String, items as Dynamic)
    row = JF_RowNode(title, items)
    if row = invalid then return
    content.appendChild(row)
    m.rowTags.Push(tag)
end sub

' After playback, refresh Continue Watching and Next Up
sub onResumed()
    if m.rows.content = invalid then return
    m.restoreFocus = m.rows.rowItemFocused
    load()
end sub

' ---- Focus and selection --------------------------------------------------------------------------------------------

function focusedNode() as Dynamic
    focus = m.rows.rowItemFocused
    content = m.rows.content
    if content = invalid or focus = invalid or focus.Count() < 2 then return invalid
    row = content.getChild(focus[0])
    if row = invalid then return invalid
    return row.getChild(focus[1])
end function

sub onItemFocused()
    node = focusedNode()
    if node <> invalid then showHero(node)
end sub

sub showHero(node as Dynamic)
    if node = invalid then return
    m.hero.match = -1
    m.hero.content = node
end sub

sub onItemSelected()
    node = focusedNode()
    if node = invalid then return
    tag = m.rowTags[m.rows.rowItemSelected[0]]
    ' Continue Watching and Next Up play straight away
    if (tag = "resume" or tag = "nextup") and node.playable
        m.top.navigate = { screen: "PlayerScreen", params: { itemId: node.itemId } }
    else
        openDetails(node)
    end if
end sub

sub openDetails(node as Object)
    itemId = node.itemId
    m.top.navigate = { screen: "DetailsScreen", params: { itemId: itemId } }
end sub

' ---- Side menu ------------------------------------------------------------------------------------------------------

sub openMenu()
    m.menu.visible = true
    m.focusTarget = m.menu
    m.menu.setFocus(true)
end sub

sub closeMenu()
    m.menu.visible = false
    m.focusTarget = m.rows
    m.rows.setFocus(true)
end sub

sub onMenu()
    choice = m.menu.selected
    closeMenu()
    if choice = "search"
        m.top.navigate = { screen: "SearchScreen" }
    else if choice = "mylist"
        m.top.navigate = { screen: "GridScreen", params: { title: "My List", query: { filters: "IsFavorite", sortBy: "DateCreated", sortOrder: "Descending" } } }
    else if choice = "profiles"
        m.top.navigate = { screen: "ProfilesScreen", reset: true }
    else if choice = "theme"
        chooseTheme()
    else if choice = "signout"
        JF_Post("/Sessions/Logout", invalid, "onSignedOut")
    else if choice = "server"
        JF_ClearSession()
        m.top.navigate = { screen: "ConnectScreen", reset: true }
    end if
end sub

' Each profile picks its own colors; the page is rebuilt in the new ones
sub chooseTheme()
    m.themes = JF_ThemeList()
    current = m.global.theme
    names = []
    for each theme in m.themes
        name = theme.name
        if current <> invalid and current.id = theme.id then name = "✓  " + name
        names.Push(name)
    end for
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Theme"
    dialog.message = ["Pick the colors for this profile."]
    dialog.buttons = names
    dialog.observeFieldScoped("buttonSelected", "onThemeChosen")
    dialog.observeFieldScoped("wasClosed", "JF_CloseDialog")
    m.top.getScene().dialog = dialog
end sub

sub onThemeChosen()
    dialog = m.top.getScene().dialog
    dialog.close = true
    theme = m.themes[dialog.buttonSelected]
    if m.global.theme <> invalid and m.global.theme.id = theme.id then return
    JF_SaveTheme(m.global.userId, theme.id)
    m.top.navigate = { screen: "HomeScreen", reset: true }
end sub

sub onSignedOut()
    JF_ClearSession()
    m.top.navigate = { screen: "LoginScreen", reset: true }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.menu.visible
        if key = "back" or key = "right"
            closeMenu()
            return true
        end if
        return false
    end if
    ' Left at the start of a row (the RowList didn't use it) opens the menu
    if key = "left" or key = "options"
        openMenu()
        return true
    else if key = "play"
        node = focusedNode()
        if node <> invalid
            m.top.navigate = { screen: "PlayerScreen", params: { itemId: node.itemId } }
            return true
        end if
    else if key = "back" and m.rows.content <> invalid
        ' Back from further down the page returns to the first row before leaving the app
        focus = m.rows.rowItemFocused
        if focus <> invalid and (focus[0] > 0 or focus[1] > 0)
            m.rows.jumpToRowItem = [0, 0]
            return true
        end if
    end if
    return false
end function
