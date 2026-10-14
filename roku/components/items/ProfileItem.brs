sub init()
    m.frame = m.top.findNode("frame")
    m.avatar = m.top.findNode("avatar")
    m.initial = m.top.findNode("initial")
    m.photo = m.top.findNode("photo")
    m.name = m.top.findNode("name")
    m.badge = m.top.findNode("badge")
end sub

sub onContent()
    content = m.top.itemContent
    if content = invalid then return
    m.name.text = content.title
    m.avatar.color = content.avatarColor
    m.initial.text = UCase(Left(content.title, 1))
    m.photo.uri = content.HDPosterUrl
    badges = []
    if content.isKids then badges.Push("Kids")
    if content.hasPin then badges.Push("PIN")
    text = ""
    for each badge in badges
        if text <> "" then text = text + "  ·  "
        text = text + badge
    end for
    m.badge.text = text
end sub

sub onFocus()
    amount = m.top.focusPercent
    if not m.top.gridHasFocus then amount = 0
    m.frame.opacity = amount
    if amount > 0.5 then m.name.color = "0xFFFFFFFF" else m.name.color = "0xB3B3B3FF"
end sub
