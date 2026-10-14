sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x141414FF"
    m.screens = m.top.findNode("screens")
    m.stack = []
    m.pendingDeepLink = invalid
end sub

sub onStarted()
    m.global.server = JF_RegistryRead("server")
    m.global.token = JF_RegistryRead("token")
    m.global.userId = JF_RegistryRead("userId")

    if m.global.server = ""
        show("ConnectScreen", {}, true)
    else if m.global.token = "" or m.global.userId = ""
        show("LoginScreen", {}, true)
    else
        ' "Who's watching?" every time the app opens, as in the web client
        show("ProfilesScreen", { startup: true }, true)
    end if
end sub

' ---- Navigation -----------------------------------------------------------------------------------------------------

' Shows screen [name]; [reset] replaces the whole stack (after signing in, switching profile…)
sub show(name as String, params as Object, reset as Boolean)
    screen = CreateObject("roSGNode", name)
    if screen = invalid
        print "[JellyFlix] unknown screen "; name
        return
    end if
    screen.observeField("navigate", "onNavigate")
    screen.observeField("close", "onClose")

    if reset
        for each old in m.stack
            m.screens.removeChild(old)
        end for
        m.stack = []
    else if m.stack.Count() > 0
        m.stack.Peek().visible = false
    end if

    m.screens.appendChild(screen)
    m.stack.Push(screen)
    screen.setFocus(true)
    screen.params = params

    if name = "HomeScreen" then openPendingDeepLink()
end sub

sub onNavigate(event as Object)
    request = event.getData()
    if request = invalid or request.screen = invalid then return
    params = request.params
    if params = invalid then params = {}
    show(request.screen, params, JF_IsTrue(request.reset))
end sub

sub onClose()
    goBack()
end sub

sub goBack()
    if m.stack.Count() <= 1
        m.top.exitApp = true
        return
    end if
    top = m.stack.Pop()
    m.screens.removeChild(top)
    previous = m.stack.Peek()
    previous.visible = true
    previous.setFocus(true)
    previous.resumed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        goBack()
        return true
    end if
    return false
end function

' ---- Deep links -----------------------------------------------------------------------------------------------------

sub onDeepLink()
    m.pendingDeepLink = m.top.deepLink
    ' Only once signed in and past "Who's watching?"
    if m.stack.Count() > 0 and m.stack[0].subtype() = "HomeScreen" then openPendingDeepLink()
end sub

sub openPendingDeepLink()
    link = m.pendingDeepLink
    if link = invalid then return
    m.pendingDeepLink = invalid
    mediaType = ""
    if link.mediaType <> invalid then mediaType = LCase(link.mediaType)
    if mediaType = "movie" or mediaType = "episode" or mediaType = "shortformvideo" or mediaType = "tvspecial"
        show("PlayerScreen", { itemId: link.contentId }, false)
    else
        show("DetailsScreen", { itemId: link.contentId }, false)
    end if
end sub
