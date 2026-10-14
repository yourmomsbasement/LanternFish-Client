sub init()
    m.heading = m.top.findNode("heading")
    m.code = m.top.findNode("code")
    m.qcStatus = m.top.findNode("qcStatus")
    m.quickConnect = m.top.findNode("quickConnect")
    m.actions = m.top.findNode("actions")
    m.status = m.top.findNode("status")
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "pollQuickConnect")

    content = CreateObject("roSGNode", "ContentNode")
    for each title in ["Sign in with password", "Change server"]
        node = content.createChild("ContentNode")
        node.title = title
    end for
    m.actions.content = content
    m.actions.observeField("itemSelected", "onAction")

    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "onParams")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.actions.setFocus(true)
end sub

sub onParams()
    name = m.top.params.serverName
    if name <> invalid and name <> ""
        m.heading.text = "Sign in to " + name
    else
        JF_Get("/System/Info/Public", invalid, "onServerInfo")
    end if
    startQuickConnect()
end sub

sub onServerInfo(event as Object)
    response = event.getRoSGNode().response
    if response.ok and response.json <> invalid and response.json.ServerName <> invalid
        m.heading.text = "Sign in to " + response.json.ServerName
    end if
end sub

' ---- Quick Connect --------------------------------------------------------------------------------------------------

sub startQuickConnect()
    m.qcStatus.text = ""
    JF_Post("/QuickConnect/Initiate", invalid, "onQuickConnectStarted")
end sub

sub onQuickConnectStarted(event as Object)
    response = event.getRoSGNode().response
    if response.ok and response.json <> invalid and response.json.Code <> invalid
        m.secret = response.json.Secret
        m.code.text = response.json.Code
        m.qcStatus.text = "Waiting for approval…"
        m.poll.control = "start"
    else
        m.code.text = "—"
        m.qcStatus.text = "Quick Connect is turned off on this server (Dashboard → General → Quick Connect). Sign in with your password instead."
    end if
end sub

sub pollQuickConnect()
    if m.secret = invalid then return
    JF_Get("/QuickConnect/Connect", { secret: m.secret }, "onQuickConnectState")
end sub

sub onQuickConnectState(event as Object)
    response = event.getRoSGNode().response
    if not response.ok
        ' The code expired (servers keep them ~10 minutes); get a new one
        m.poll.control = "stop"
        startQuickConnect()
        return
    end if
    if response.json <> invalid and JF_IsTrue(response.json.Authenticated)
        m.poll.control = "stop"
        m.qcStatus.text = "Approved. Signing in…"
        JF_Post("/Users/AuthenticateWithQuickConnect", { Secret: m.secret }, "onAuthenticated")
    end if
end sub

' ---- Password -------------------------------------------------------------------------------------------------------

sub onAction()
    if m.actions.itemSelected = 0
        askUsername()
    else
        m.poll.control = "stop"
        m.top.navigate = { screen: "ConnectScreen", reset: true }
    end if
end sub

sub askUsername()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "Username"
    dialog.buttons = ["Next", "Cancel"]
    dialog.text = JF_RegistryRead("username")
    dialog.observeFieldScoped("buttonSelected", "onUsername")
    dialog.observeFieldScoped("wasClosed", "JF_CloseDialog")
    m.top.getScene().dialog = dialog
end sub

sub onUsername()
    dialog = m.top.getScene().dialog
    dialog.close = true
    if dialog.buttonSelected <> 0 or dialog.text.Trim() = "" then return
    m.username = dialog.text.Trim()

    password = CreateObject("roSGNode", "StandardKeyboardDialog")
    password.title = "Password for " + m.username
    password.buttons = ["Sign in", "Cancel"]
    password.textEditBox.secureMode = true
    password.observeFieldScoped("buttonSelected", "onPassword")
    password.observeFieldScoped("wasClosed", "JF_CloseDialog")
    m.top.getScene().dialog = password
end sub

sub onPassword()
    dialog = m.top.getScene().dialog
    dialog.close = true
    if dialog.buttonSelected <> 0 then return
    m.status.text = "Signing in…"
    JF_Post("/Users/AuthenticateByName", { Username: m.username, Pw: dialog.text }, "onAuthenticated")
end sub

' ---- Signed in ------------------------------------------------------------------------------------------------------

sub onAuthenticated(event as Object)
    response = event.getRoSGNode().response
    if response.ok and response.json <> invalid and response.json.AccessToken <> invalid
        m.poll.control = "stop"
        if m.username <> invalid then JF_RegistryWrite("username", m.username)
        JF_SaveSession(response.json)
        m.top.navigate = { screen: "ProfilesScreen", params: { startup: true }, reset: true }
    else if response.code = 401
        m.status.text = "Wrong username or password."
    else
        m.status.text = "Couldn't sign in: " + response.error
    end if
end sub
