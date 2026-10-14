sub init()
    JF_ApplyTheme(m.top)
    m.keyboard = m.top.findNode("keyboard")
    m.hint = m.top.findNode("hint")
    m.results = m.top.findNode("results")
    m.debounce = m.top.findNode("debounce")
    m.focusTarget = m.keyboard
    m.query = ""
    m.found = {}

    m.keyboard.observeField("text", "onTextChanged")
    m.debounce.observeField("fire", "search")
    m.results.observeField("rowItemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusTarget.setFocus(true)
end sub

sub onTextChanged()
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub search()
    query = m.keyboard.text.Trim()
    if query = m.query then return
    m.query = query
    m.found = {}
    if Len(query) < 2
        m.results.content = invalid
        m.hint.visible = true
        return
    end if
    JF_Get("/Items", {
        userId: m.global.userId,
        searchTerm: query,
        recursive: true,
        includeItemTypes: "Movie,Series,Episode",
        limit: 40,
        fields: JF_ItemFields(),
        enableImageTypes: "Primary,Backdrop,Logo",
        imageTypeLimit: 1
    }, "onResults", query + "|titles")
    if Len(query) >= 3
        JF_Get("/JellyFlix/Search", { query: query, limit: 20 }, "onResults", query + "|description")
    end if
end sub

sub onResults(event as Object)
    task = event.getRoSGNode()
    parts = task.tag.Split("|")
    if parts[0] <> m.query then return
    response = task.response
    items = []
    if response.ok and response.json <> invalid and response.json.Items <> invalid then items = response.json.Items
    m.found[parts[1]] = items
    render()
end sub

sub render()
    content = CreateObject("roSGNode", "ContentNode")
    titles = m.found.titles
    shown = {}
    if titles <> invalid
        row = JF_RowNode("Results", titles)
        if row <> invalid then content.appendChild(row)
        for each item in titles
            shown[item.Id] = true
        end for
    end if
    ' Titles the name search already shows are left out, as in the web client
    description = m.found.description
    if description <> invalid
        extra = []
        for each item in description
            if shown[item.Id] = invalid then extra.Push(item)
        end for
        row = JF_RowNode("Matches your description", extra)
        if row <> invalid then content.appendChild(row)
    end if

    if content.getChildCount() = 0
        m.results.content = invalid
        if titles <> invalid
            m.hint.text = "Nothing found for " + Chr(34) + m.query + Chr(34) + "."
            m.hint.visible = true
        end if
        return
    end if
    m.hint.visible = false
    m.results.content = content
end sub

sub onSelected()
    focus = m.results.rowItemSelected
    node = m.results.content.getChild(focus[0]).getChild(focus[1])
    m.top.navigate = { screen: "DetailsScreen", params: { itemId: node.itemId } }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "right" and m.keyboard.isInFocusChain() and m.results.content <> invalid
        m.focusTarget = m.results
        m.results.setFocus(true)
        return true
    else if (key = "left" or key = "back") and m.results.isInFocusChain()
        m.focusTarget = m.keyboard
        m.keyboard.setFocus(true)
        return true
    else if key = "play" and m.results.isInFocusChain()
        focus = m.results.rowItemFocused
        node = m.results.content.getChild(focus[0]).getChild(focus[1])
        m.top.navigate = { screen: "PlayerScreen", params: { itemId: node.itemId } }
        return true
    end if
    return false
end function
