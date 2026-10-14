sub init()
    m.title = m.top.findNode("title")
    m.grid = m.top.findNode("grid")
    m.empty = m.top.findNode("empty")
    m.spinner = m.top.findNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.grid.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "load")
    m.top.observeField("resumed", "load")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.grid.setFocus(true)
end sub

sub load()
    params = m.top.params
    m.title.text = params.title
    query = { userId: m.global.userId, recursive: true, includeItemTypes: "Movie,Series", fields: JF_ItemFields(), enableImageTypes: "Primary,Backdrop,Logo", imageTypeLimit: 1, limit: 200 }
    query.Append(params.query)
    m.spinner.visible = true
    m.spinner.control = "start"
    JF_Get("/Items", query, "onItems")
end sub

sub onItems(event as Object)
    m.spinner.control = "stop"
    m.spinner.visible = false
    response = event.getRoSGNode().response
    items = []
    if response.ok and response.json <> invalid and response.json.Items <> invalid then items = response.json.Items
    content = CreateObject("roSGNode", "ContentNode")
    for each item in items
        JF_ItemNode(item, content)
    end for
    focused = m.grid.itemFocused
    m.grid.content = content
    if focused > 0 and focused < items.Count() then m.grid.jumpToItem = focused
    m.empty.visible = items.Count() = 0
    m.empty.text = "Nothing here yet. Add titles with + My List on any title page."
end sub

sub onSelected()
    node = m.grid.content.getChild(m.grid.itemSelected)
    m.top.navigate = { screen: "DetailsScreen", params: { itemId: node.itemId } }
end sub
