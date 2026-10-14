' Helpers shared by every Lanternfish component. Include with
'   <script type="text/brightscript" uri="pkg:/components/common/Utils.brs" />

' ---- Colors and text ------------------------------------------------------------------------------------------------

' "#E50914" (the web client's avatar colors) -> "0xE50914FF"
function JF_HexColor(hex as Dynamic, fallback = "0xE50914FF" as String) as String
    if hex = invalid then return fallback
    value = hex.Trim()
    if Left(value, 1) = "#" then value = Mid(value, 2)
    if Len(value) = 3 then value = Mid(value, 1, 1) + Mid(value, 1, 1) + Mid(value, 2, 1) + Mid(value, 2, 1) + Mid(value, 3, 1) + Mid(value, 3, 1)
    if Len(value) <> 6 then return fallback
    value = UCase(value)
    for i = 1 to 6
        if Instr(1, "0123456789ABCDEF", Mid(value, i, 1)) = 0 then return fallback
    end for
    return "0x" + value + "FF"
end function

' 63_000_000_000 ticks -> "1h 45m"
function JF_Runtime(ticks as Dynamic) as String
    if ticks = invalid or ticks <= 0 then return ""
    minutes = Int(ticks / 600000000)
    if minutes < 60 then return minutes.ToStr() + "m"
    hours = Int(minutes / 60)
    rest = minutes - hours * 60
    if rest = 0 then return hours.ToStr() + "h"
    return hours.ToStr() + "h " + rest.ToStr() + "m"
end function

' "S2:E5"
function JF_EpisodeCode(item as Object) as String
    if item.ParentIndexNumber = invalid or item.IndexNumber = invalid then return ""
    return "S" + item.ParentIndexNumber.ToStr() + ":E" + item.IndexNumber.ToStr()
end function

' "2019 · PG-13 · 2h 1m" (for shows, the season count when known)
function JF_MetaLine(item as Object) as String
    parts = []
    if item.ProductionYear <> invalid then parts.Push(item.ProductionYear.ToStr())
    if item.OfficialRating <> invalid and item.OfficialRating <> "" then parts.Push(item.OfficialRating)
    if item.Type = "Series"
        if item.ChildCount <> invalid and item.ChildCount > 0
            if item.ChildCount = 1 then parts.Push("1 Season") else parts.Push(item.ChildCount.ToStr() + " Seasons")
        end if
    else
        runtime = JF_Runtime(item.RunTimeTicks)
        if runtime <> "" then parts.Push(runtime)
    end if
    return JF_Join(parts, "  ·  ")
end function

function JF_Join(parts as Object, separator as String) as String
    text = ""
    for i = 0 to parts.Count() - 1
        if i > 0 then text = text + separator
        text = text + parts[i]
    end for
    return text
end function

' The first [count] names of an item's people of a type, e.g. "Actor"
function JF_People(item as Object, kind as String, count as Integer) as String
    names = []
    if item.People <> invalid
        for each person in item.People
            if person.Type = kind and names.Count() < count then names.Push(person.Name)
        end for
    end if
    return JF_Join(names, ", ")
end function

' Played fraction (0..1) of an item, from its UserData
function JF_Progress(item as Object) as Float
    data = item.UserData
    if data = invalid then return 0
    if data.PlayedPercentage <> invalid then return data.PlayedPercentage / 100
    if data.PlaybackPositionTicks <> invalid and item.RunTimeTicks <> invalid and item.RunTimeTicks > 0
        return data.PlaybackPositionTicks / item.RunTimeTicks
    end if
    return 0
end function

function JF_IsTrue(value as Dynamic) as Boolean
    if value = invalid or GetInterface(value, "ifBoolean") = invalid then return false
    return value
end function

function JF_IsPlayed(item as Object) as Boolean
    if item.UserData = invalid then return false
    return JF_IsTrue(item.UserData.Played)
end function

' ---- Images ---------------------------------------------------------------------------------------------------------

' Jellyfin's ids come without dashes; the plugin's artwork map may have them either way
function JF_NormalizeId(id as Dynamic) as String
    if id = invalid then return ""
    return LCase(id.Replace("-", ""))
end function

function JF_ImageUrl(itemId as String, imageType as String, tag as Dynamic, sizeQuery as String) as String
    url = m.global.server + "/Items/" + itemId + "/Images/" + imageType + "?quality=90&" + sizeQuery
    if tag <> invalid and tag <> "" then url = url + "&tag=" + tag
    return url
end function

' A path the JellyFlix plugin returned for the profile's chosen artwork ("JellyFlix/Artwork/Images/…")
function JF_ArtworkOverride(itemId as String, kind as String, sizeQuery as String) as String
    artwork = m.global.artwork
    if artwork = invalid then return ""
    choice = artwork[JF_NormalizeId(itemId)]
    if choice = invalid or choice[kind] = invalid or choice[kind] = "" then return ""
    path = choice[kind]
    if Left(path, 1) = "/" then path = Mid(path, 2)
    joiner = "?"
    if Instr(1, path, "?") > 0 then joiner = "&"
    return m.global.server + "/" + path + joiner + sizeQuery
end function

' 2:3 poster; episodes show their show's poster
function JF_PosterUrl(item as Object, height = 450 as Integer) as String
    size = "fillHeight=" + height.ToStr()
    itemId = item.Id
    tag = invalid
    if item.ImageTags <> invalid then tag = item.ImageTags.Primary
    if (item.Type = "Episode" or item.Type = "Season") and item.SeriesId <> invalid
        itemId = item.SeriesId
        tag = item.SeriesPrimaryImageTag
    end if
    override = JF_ArtworkOverride(itemId, "Poster", size)
    if override <> "" then return override
    if tag = invalid and item.Type <> "Episode" and item.Type <> "Season" then return ""
    return JF_ImageUrl(itemId, "Primary", tag, size)
end function

' 16:9 backdrop; episodes fall back to their show's
function JF_BackdropUrl(item as Object, width = 1920 as Integer) as String
    size = "fillWidth=" + width.ToStr()
    if item.BackdropImageTags <> invalid and item.BackdropImageTags.Count() > 0
        override = JF_ArtworkOverride(item.Id, "Backdrop", size)
        if override <> "" then return override
        return JF_ImageUrl(item.Id, "Backdrop", item.BackdropImageTags[0], size)
    end if
    parentId = item.ParentBackdropItemId
    if parentId = invalid then parentId = item.SeriesId
    if parentId <> invalid
        override = JF_ArtworkOverride(parentId, "Backdrop", size)
        if override <> "" then return override
        tag = invalid
        if item.ParentBackdropImageTags <> invalid and item.ParentBackdropImageTags.Count() > 0 then tag = item.ParentBackdropImageTags[0]
        if tag <> invalid then return JF_ImageUrl(parentId, "Backdrop", tag, size)
    end if
    return ""
end function

' Title art ("logo"); empty when the title has none
function JF_LogoUrl(item as Object) as String
    size = "fillHeight=200"
    if item.ImageTags <> invalid and item.ImageTags.Logo <> invalid
        return JF_ImageUrl(item.Id, "Logo", item.ImageTags.Logo, size)
    end if
    if item.ParentLogoItemId <> invalid and item.ParentLogoImageTag <> invalid
        return JF_ImageUrl(item.ParentLogoItemId, "Logo", item.ParentLogoImageTag, size)
    end if
    return ""
end function

' 16:9 still for an episode, else its backdrop
function JF_ThumbUrl(item as Object, width = 480 as Integer) as String
    if item.ImageTags <> invalid and item.ImageTags.Primary <> invalid and item.Type = "Episode"
        return JF_ImageUrl(item.Id, "Primary", item.ImageTags.Primary, "fillWidth=" + width.ToStr())
    end if
    if item.ImageTags <> invalid and item.ImageTags.Thumb <> invalid
        return JF_ImageUrl(item.Id, "Thumb", item.ImageTags.Thumb, "fillWidth=" + width.ToStr())
    end if
    return JF_BackdropUrl(item, width)
end function

function JF_UserImageUrl(userId as String, tag as Dynamic, size = 300 as Integer) as String
    if tag = invalid or tag = "" then return ""
    return m.global.server + "/Users/" + userId + "/Images/Primary?tag=" + tag + "&fillWidth=" + size.ToStr() + "&fillHeight=" + size.ToStr() + "&quality=90"
end function

' ---- Content nodes --------------------------------------------------------------------------------------------------

' A poster ContentNode for a BaseItemDto; RowLists and grids render these with PosterItem
function JF_ItemNode(item as Object, parent = invalid as Dynamic) as Object
    node = CreateObject("roSGNode", "ContentNode")
    node.addFields({
        itemId: item.Id,
        itemType: item.Type,
        seriesId: "",
        backdropUrl: JF_BackdropUrl(item),
        logoUrl: JF_LogoUrl(item),
        meta: JF_MetaLine(item),
        subtitle: "",
        progress: JF_Progress(item),
        played: JF_IsPlayed(item),
        playable: item.Type = "Movie" or item.Type = "Episode" or item.Type = "Video" or item.Type = "MusicVideo"
    })
    node.title = item.Name
    node.description = ""
    if item.Overview <> invalid then node.description = item.Overview
    node.HDPosterUrl = JF_PosterUrl(item)
    if item.SeriesId <> invalid then node.seriesId = item.SeriesId
    if item.Type = "Episode"
        node.subtitle = JF_EpisodeCode(item) + "  " + item.Name
        if item.SeriesName <> invalid then node.title = item.SeriesName
    end if
    if parent <> invalid then parent.appendChild(node)
    return node
end function

' A row ContentNode titled [title] with a poster for each item; invalid when there are no items
function JF_RowNode(title as String, items as Dynamic) as Dynamic
    if items = invalid or items.Count() = 0 then return invalid
    row = CreateObject("roSGNode", "ContentNode")
    row.title = title
    for each item in items
        JF_ItemNode(item, row)
    end for
    return row
end function

' ---- Registry -------------------------------------------------------------------------------------------------------

function JF_RegistryRead(key as String) as String
    section = CreateObject("roRegistrySection", "lanternfish")
    if section.Exists(key) then return section.Read(key)
    return ""
end function

sub JF_RegistryWrite(key as String, value as String)
    section = CreateObject("roRegistrySection", "lanternfish")
    section.Write(key, value)
    section.Flush()
end sub

sub JF_RegistryDelete(key as String)
    section = CreateObject("roRegistrySection", "lanternfish")
    section.Delete(key)
    section.Flush()
end sub

' Signs in this device: remembers the session and makes it the one every request uses
sub JF_SaveSession(auth as Object)
    m.global.token = auth.AccessToken
    m.global.userId = auth.User.Id
    m.global.artwork = {}
    JF_RegistryWrite("token", auth.AccessToken)
    JF_RegistryWrite("userId", auth.User.Id)
    JF_LoadTheme(auth.User.Id)
end sub

sub JF_ClearSession()
    m.global.token = ""
    m.global.userId = ""
    m.global.artwork = {}
    JF_RegistryDelete("token")
    JF_RegistryDelete("userId")
end sub

' ---- Requests -------------------------------------------------------------------------------------------------------

' Starts an ApiTask; [callback] (a function name on this component) gets the task node, whose `response` holds
' { ok, code, json, error } and whose `tag` is [tag]
function JF_Request(method as String, path as String, query as Dynamic, body as Dynamic, callback as String, tag = "" as String) as Object
    task = CreateObject("roSGNode", "ApiTask")
    task.tag = tag
    task.request = { method: method, path: path, query: query, body: body }
    task.observeField("response", callback)
    task.control = "run"
    ' Keep a reference until the task finishes, dropping the finished ones
    if m.jfTasks = invalid then m.jfTasks = []
    running = [task]
    for each other in m.jfTasks
        if other.state = "run" or other.state = "init" then running.Push(other)
    end for
    m.jfTasks = running
    return task
end function

function JF_Get(path as String, query as Dynamic, callback as String, tag = "" as String) as Object
    return JF_Request("GET", path, query, invalid, callback, tag)
end function

function JF_Post(path as String, body as Dynamic, callback as String, tag = "" as String) as Object
    return JF_Request("POST", path, invalid, body, callback, tag)
end function

' The fields every item request asks for
function JF_ItemFields() as String
    return "Overview,Genres,PrimaryImageAspectRatio,ChildCount"
end function

' ---- Dialogs --------------------------------------------------------------------------------------------------------

sub JF_ShowMessage(title as String, message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = title
    dialog.message = [message]
    dialog.buttons = ["OK"]
    dialog.observeFieldScoped("buttonSelected", "JF_CloseDialog")
    dialog.observeFieldScoped("wasClosed", "JF_CloseDialog")
    m.top.getScene().dialog = dialog
end sub

sub JF_CloseDialog()
    dialog = m.top.getScene().dialog
    if dialog <> invalid then dialog.close = true
end sub
