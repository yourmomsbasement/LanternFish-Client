sub init()
    m.frame = m.top.findNode("frame")
    m.placeholder = m.top.findNode("placeholder")
    m.fallback = m.top.findNode("fallback")
    m.poster = m.top.findNode("poster")
    m.track = m.top.findNode("track")
    m.bar = m.top.findNode("bar")
    m.caption = m.top.findNode("caption")
end sub

sub onSize()
    w = m.top.width
    h = m.top.height
    if w = 0 or h = 0 then return
    m.frame.width = w + 10
    m.frame.height = h + 10
    m.placeholder.width = w
    m.placeholder.height = h
    m.fallback.width = w - 24
    m.fallback.height = h
    m.poster.width = w
    m.poster.height = h
    m.poster.loadWidth = w
    m.poster.loadHeight = h
    m.track.width = w - 24
    m.track.translation = [12, h - 18]
    m.bar.translation = [12, h - 18]
    m.caption.width = w
    m.caption.translation = [0, h + 10]
    updateProgress()
end sub

sub onContent()
    content = m.top.itemContent
    if content = invalid then return
    m.fallback.text = content.title
    m.poster.uri = content.HDPosterUrl
    updateProgress()
end sub

sub updateProgress()
    content = m.top.itemContent
    if content = invalid or m.top.width = 0 then return
    progress = 0
    if content.hasField("progress") then progress = content.progress
    started = progress > 0.01 and progress < 0.97
    m.track.visible = started
    m.bar.visible = started
    if started then m.bar.width = (m.top.width - 24) * progress
end sub

sub onFocus()
    listFocused = m.top.rowListHasFocus or m.top.gridHasFocus
    amount = m.top.focusPercent
    if m.top.rowFocusPercent > 0 or m.top.rowListHasFocus then amount = amount * m.top.rowFocusPercent
    if not listFocused then amount = 0
    m.frame.opacity = amount
end sub
