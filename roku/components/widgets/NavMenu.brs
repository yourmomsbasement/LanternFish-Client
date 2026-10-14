sub init()
    JF_ApplyTheme(m.top)
    m.list = m.top.findNode("list")
    m.profile = m.top.findNode("profile")
    m.entries = [
        { id: "search", title: "Search" },
        { id: "home", title: "Home" },
        { id: "mylist", title: "My List" },
        { id: "profiles", title: "Switch Profile" },
        { id: "theme", title: "Theme" },
        { id: "signout", title: "Sign Out" },
        { id: "server", title: "Change Server" }
    ]
    content = CreateObject("roSGNode", "ContentNode")
    for each entry in m.entries
        node = content.createChild("ContentNode")
        node.title = entry.title
    end for
    m.list.content = content
    m.list.jumpToItem = 1
    m.list.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

sub onProfileName()
    m.profile.text = m.top.profileName
end sub

sub onItemSelected()
    m.top.selected = m.entries[m.list.itemSelected].id
end sub
