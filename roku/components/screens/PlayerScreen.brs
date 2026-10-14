sub init()
    m.video = m.top.findNode("video")
    m.spinner = m.top.findNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.progress = m.top.findNode("progress")
    m.progress.observeField("fire", "reportProgress")
    m.video.observeField("state", "onState")
    m.session = invalid
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "load")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.video.setFocus(true)
end sub

sub load()
    showSpinner(true)
    m.fromBeginning = JF_IsTrue(m.top.params.fromBeginning)
    JF_Get("/Items/" + m.top.params.itemId, { userId: m.global.userId }, "onItem")
end sub

sub showSpinner(visible as Boolean)
    m.spinner.visible = visible
    if visible then m.spinner.control = "start" else m.spinner.control = "stop"
end sub

sub onItem(event as Object)
    response = event.getRoSGNode().response
    if not response.ok or response.json = invalid
        fail("Couldn't open this title: " + response.error)
        return
    end if
    item = response.json
    if item.Type = "Series" or item.Type = "Season"
        ' Play a show from its next episode
        query = { userId: m.global.userId, seriesId: item.Id, limit: 1 }
        if item.Type = "Season" then query.seriesId = item.SeriesId
        JF_Get("/Shows/NextUp", query, "onSeriesEpisode")
        return
    end if
    play(item, false)
end sub

sub onSeriesEpisode(event as Object)
    response = event.getRoSGNode().response
    if response.ok and response.json <> invalid and response.json.Items <> invalid and response.json.Items.Count() > 0
        play(response.json.Items[0], false)
    else
        fail("There's no episode to play next.")
    end if
end sub

' ---- Starting playback ----------------------------------------------------------------------------------------------

sub play(item as Object, forceTranscode as Boolean)
    m.item = item
    m.forceTranscode = forceTranscode
    m.started = false
    startTicks = 0&
    if not m.fromBeginning and item.UserData <> invalid and item.UserData.PlaybackPositionTicks <> invalid and not JF_IsPlayed(item)
        startTicks = item.UserData.PlaybackPositionTicks
    end if
    m.startTicks = startTicks

    body = {
        UserId: m.global.userId,
        DeviceProfile: JF_DeviceProfile(),
        StartTimeTicks: startTicks,
        AutoOpenLiveStream: true,
        EnableDirectPlay: not forceTranscode,
        EnableDirectStream: not forceTranscode,
        EnableTranscoding: true,
        AllowVideoStreamCopy: not forceTranscode,
        AllowAudioStreamCopy: not forceTranscode
    }
    showSpinner(true)
    JF_Request("POST", "/Items/" + item.Id + "/PlaybackInfo", { userId: m.global.userId }, body, "onPlaybackInfo")
end sub

sub onPlaybackInfo(event as Object)
    response = event.getRoSGNode().response
    info = response.json
    if not response.ok or info = invalid or info.MediaSources = invalid or info.MediaSources.Count() = 0
        fail("This title can't be played: " + response.error)
        return
    end if
    if info.ErrorCode <> invalid
        fail("This title can't be played (" + info.ErrorCode + ").")
        return
    end if

    source = info.MediaSources[0]
    item = m.item
    content = CreateObject("roSGNode", "ContentNode")
    content.title = item.Name
    if item.Type = "Episode" and item.SeriesName <> invalid
        content.title = item.SeriesName + "  ·  " + JF_EpisodeCode(item) + "  " + item.Name
    end if
    content.HttpHeaders = ["Authorization: " + authHeader()]

    if not m.forceTranscode and JF_IsTrue(source.SupportsDirectPlay)
        m.playMethod = "DirectPlay"
        query = "static=true&mediaSourceId=" + source.Id + "&playSessionId=" + info.PlaySessionId + "&deviceId=" + m.global.deviceId
        if source.ETag <> invalid then query = query + "&tag=" + source.ETag
        content.url = m.global.server + "/Videos/" + item.Id + "/stream?" + query
        content.streamFormat = streamFormat(source.Container)
    else if source.TranscodingUrl <> invalid
        m.playMethod = "Transcode"
        if JF_IsTrue(source.SupportsDirectStream) then m.playMethod = "DirectStream"
        content.url = m.global.server + source.TranscodingUrl
        content.streamFormat = "hls"
    else
        fail("The server didn't offer a way to play this title on Roku.")
        return
    end if

    ' External text subtitles; Roku's own caption menu picks between them
    tracks = []
    if source.MediaStreams <> invalid
        for each stream in source.MediaStreams
            if stream.Type = "Subtitle" and stream.DeliveryMethod = "External" and stream.DeliveryUrl <> invalid
                language = "und"
                if stream.Language <> invalid then language = stream.Language
                name = language
                if stream.DisplayTitle <> invalid then name = stream.DisplayTitle
                tracks.Push({ Language: language, Description: name, TrackName: m.global.server + stream.DeliveryUrl })
            end if
        end for
    end if
    if tracks.Count() > 0 then content.SubtitleTracks = tracks

    if m.startTicks > 0 then content.PlayStart = Int(m.startTicks / 10000000)

    m.session = { itemId: item.Id, mediaSourceId: source.Id, playSessionId: info.PlaySessionId }
    m.video.content = content
    m.video.control = "play"
    m.video.setFocus(true)
end sub

function streamFormat(container as Dynamic) as String
    if container = invalid then return "mp4"
    value = LCase(container)
    if Instr(1, value, "mkv") > 0 or Instr(1, value, "matroska") > 0 then return "mkv"
    if Instr(1, value, "m3u8") > 0 or Instr(1, value, "hls") > 0 then return "hls"
    return "mp4"
end function

' The Authorization header the ApiTask sends, for the Video node's own requests
function authHeader() as String
    q = Chr(34)
    header = "MediaBrowser Client=" + q + "JellyFlix for Roku" + q + ", Device=" + q + m.global.deviceName.Replace(q, "'") + q
    header = header + ", DeviceId=" + q + m.global.deviceId + q + ", Version=" + q + m.global.appVersion + q
    return header + ", Token=" + q + m.global.token + q
end function

' ---- Playback state -------------------------------------------------------------------------------------------------

sub onState()
    state = m.video.state
    if state = "playing"
        showSpinner(false)
        if not m.started
            m.started = true
            report("/Sessions/Playing", false)
            m.progress.control = "start"
        else
            report("/Sessions/Playing/Progress", false)
        end if
    else if state = "paused"
        report("/Sessions/Playing/Progress", true)
    else if state = "buffering"
        ' The Video node shows its own buffering bar
    else if state = "finished"
        stopReporting()
        playNext()
    else if state = "error"
        print "[JellyFlix] playback error "; m.video.errorCode; " "; m.video.errorMsg
        stopReporting()
        if not m.forceTranscode
            ' Direct play didn't work out (an unexpected codec, a bad file): let the server transcode
            m.fromBeginning = false
            item = m.item
            if m.video.position > 5
                if item.UserData = invalid then item.UserData = {}
                item.UserData.PlaybackPositionTicks = JF_SecondsToTicks(m.video.position)
            end if
            play(item, true)
        else
            fail("Playback failed: " + m.video.errorMsg)
        end if
    end if
end sub

sub reportProgress()
    if m.video.state = "playing" then report("/Sessions/Playing/Progress", false)
end sub

sub report(path as String, paused as Boolean)
    if m.session = invalid then return
    body = {
        ItemId: m.session.itemId,
        MediaSourceId: m.session.mediaSourceId,
        PlaySessionId: m.session.playSessionId,
        PositionTicks: JF_SecondsToTicks(m.video.position),
        IsPaused: paused,
        PlayMethod: m.playMethod,
        CanSeek: true
    }
    JF_Post(path, body, "onReported")
end sub

sub onReported()
end sub

sub stopReporting()
    m.progress.control = "stop"
    if m.session = invalid then return
    report("/Sessions/Playing/Stopped", false)
    if m.playMethod <> "DirectPlay"
        JF_Request("DELETE", "/Videos/ActiveEncodings", { deviceId: m.global.deviceId, playSessionId: m.session.playSessionId }, invalid, "onReported")
    end if
    m.session = invalid
end sub

' ---- After playback -------------------------------------------------------------------------------------------------

sub playNext()
    if m.item.Type <> "Episode" or m.item.SeriesId = invalid
        m.top.close = true
        return
    end if
    showSpinner(true)
    JF_Get("/Shows/NextUp", { userId: m.global.userId, seriesId: m.item.SeriesId, limit: 1 }, "onNextEpisode")
end sub

sub onNextEpisode(event as Object)
    response = event.getRoSGNode().response
    if response.ok and response.json <> invalid and response.json.Items <> invalid and response.json.Items.Count() > 0
        nextItem = response.json.Items[0]
        if nextItem.Id <> m.item.Id
            m.fromBeginning = true
            play(nextItem, false)
            return
        end if
    end if
    m.top.close = true
end sub

sub fail(message as String)
    showSpinner(false)
    stopReporting()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Can't play"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    dialog.observeFieldScoped("buttonSelected", "onFailClosed")
    dialog.observeFieldScoped("wasClosed", "onFailClosed")
    m.top.getScene().dialog = dialog
end sub

sub onFailClosed()
    dialog = m.top.getScene().dialog
    if dialog <> invalid then dialog.close = true
    m.top.close = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        m.video.control = "stop"
        stopReporting()
        m.top.close = true
        return true
    end if
    return false
end function
