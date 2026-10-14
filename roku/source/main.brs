' JellyFlix for Roku
'
' A native SceneGraph client for Jellyfin servers running the JellyFlix plugin: "Who's watching?" profiles, a
' Netflix-style home of poster rows with recommendations, title pages, episodes, search and playback.

sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)

    info = CreateObject("roDeviceInfo")
    appInfo = CreateObject("roAppInfo")
    globals = screen.getGlobalNode()
    globals.addFields({
        server: "",
        token: "",
        userId: "",
        artwork: {},
        theme: {},
        deviceId: info.GetChannelClientId(),
        deviceName: DeviceName(info),
        appVersion: appInfo.GetVersion()
    })

    scene = screen.CreateScene("MainScene")
    screen.show()
    scene.observeField("exitApp", port)

    ' Deep link from the home screen or a search result (certification requirement)
    if args <> invalid and args.contentId <> invalid and args.contentId <> ""
        scene.deepLink = { contentId: args.contentId, mediaType: args.mediaType }
    end if
    scene.started = true

    input = CreateObject("roInput")
    input.setMessagePort(port)

    while true
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if msgType = "roSGNodeEvent"
            if msg.getField() = "exitApp" and msg.getData() = true
                screen.close()
                return
            end if
        else if msgType = "roInputEvent"
            if msg.isInput()
                inputInfo = msg.getInfo()
                if inputInfo.contentId <> invalid
                    scene.deepLink = { contentId: inputInfo.contentId, mediaType: inputInfo.mediaType }
                end if
            end if
        end if
    end while
end sub

' "Living Room Roku" when the user named the device, else the model ("Roku Ultra")
function DeviceName(info as Object) as String
    name = info.GetFriendlyName()
    if name = invalid or name = "" then name = info.GetModelDisplayName()
    if name = invalid or name = "" then name = "Roku"
    return name
end function
