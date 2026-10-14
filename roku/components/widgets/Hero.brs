sub init()
    JF_ApplyTheme(m.top)
    m.backdrop = m.top.findNode("backdrop")
    m.fadeLeft = m.top.findNode("fadeLeft")
    m.fadeBottom = m.top.findNode("fadeBottom")
    m.logo = m.top.findNode("logo")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.metaRow = m.top.findNode("metaRow")
    m.matchLabel = m.top.findNode("match")
    m.meta = m.top.findNode("meta")
    m.overview = m.top.findNode("overview")
    ' Moving quickly along a row shouldn't load every backdrop on the way
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "loadImages")
    m.logo.observeField("loadStatus", "onLogoStatus")
end sub

sub onLayout()
    m.overview.maxLines = m.top.overviewLines
    if m.top.fullScreen
        m.backdrop.translation = [0, 0]
        m.backdrop.width = 1920
        m.backdrop.height = 1080
        m.backdrop.loadWidth = 1920
        m.backdrop.loadHeight = 1080
        m.fadeLeft.translation = [0, 0]
        m.fadeLeft.width = 1400
        m.fadeLeft.height = 1080
        m.fadeBottom.translation = [0, 600]
        m.fadeBottom.height = 480
    end if
end sub

sub onContent()
    content = m.top.content
    if content = invalid then return

    m.title.text = content.title
    m.logo.uri = ""
    m.title.visible = true

    hasSubtitle = content.hasField("subtitle") and content.subtitle <> ""
    m.subtitle.text = ""
    if hasSubtitle then m.subtitle.text = content.subtitle
    y = 352
    if hasSubtitle then y = 400
    m.metaRow.translation = [120, y]
    m.overview.translation = [120, y + 52]

    matchText = ""
    if m.top.match >= 0 then matchText = m.top.match.ToStr() + "% Match"
    m.matchLabel.text = matchText
    m.meta.text = content.meta
    if matchText <> ""
        rect = m.matchLabel.boundingRect()
        m.meta.translation = [rect.width + 24, 0]
    else
        m.meta.translation = [0, 0]
    end if
    m.overview.text = content.description

    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub loadImages()
    content = m.top.content
    if content = invalid then return
    m.backdrop.uri = content.backdropUrl
    if content.logoUrl <> "" then m.logo.uri = content.logoUrl
end sub

' Title art replaces the title text once it has loaded
sub onLogoStatus()
    m.title.visible = m.logo.loadStatus <> "ready"
end sub
