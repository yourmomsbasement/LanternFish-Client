sub init()
    JF_ApplyTheme(m.top)
    m.highlight = m.top.findNode("highlight")
    m.still = m.top.findNode("still")
    m.track = m.top.findNode("track")
    m.bar = m.top.findNode("bar")
    m.title = m.top.findNode("title")
    m.runtime = m.top.findNode("runtime")
    m.overview = m.top.findNode("overview")
end sub

sub onContent()
    content = m.top.itemContent
    if content = invalid then return
    m.title.text = content.episodeTitle
    m.runtime.text = content.runtime
    m.overview.text = content.description
    m.still.uri = content.HDPosterUrl
    progress = content.progress
    started = progress > 0.01 and progress < 0.97
    m.track.visible = started
    m.bar.visible = started
    if started then m.bar.width = 300 * progress
end sub

sub onFocus()
    amount = m.top.focusPercent
    if not m.top.listHasFocus then amount = 0
    m.highlight.opacity = amount
end sub
