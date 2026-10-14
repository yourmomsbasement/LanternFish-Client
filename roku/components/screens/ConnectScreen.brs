sub init()
    m.options = m.top.findNode("options")
    m.status = m.top.findNode("status")
    m.spinner = m.top.findNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.servers = []
    m.candidates = []
    m.busy = false
    m.options.observeField("itemSelected", "onOptionSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "onParams")
    renderOptions()
end sub

sub onParams()
    m.status.text = "Looking for servers on your network…"
    m.discovery = CreateObject("roSGNode", "DiscoveryTask")
    m.discovery.observeField("servers", "onServersFound")
    m.discovery.control = "run"
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.options.setFocus(true)
end sub

sub onServersFound()
    m.servers = m.discovery.servers
    if m.servers.Count() = 0
        m.status.text = "No servers found on your network. Enter the address instead."
    else
        m.status.text = ""
    end if
    renderOptions()
end sub

sub renderOptions()
    content = CreateObject("roSGNode", "ContentNode")
    for each server in m.servers
        node = content.createChild("ContentNode")
        node.title = server.Name + "  —  " + server.Address
    end for
    manual = content.createChild("ContentNode")
    manual.title = "Enter server address"
    m.options.content = content
end sub

sub onOptionSelected()
    if m.busy then return
    index = m.options.itemSelected
    if index < m.servers.Count()
        connect(m.servers[index].Address)
    else
        askForAddress()
    end if
end sub

sub askForAddress()
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "Server address"
    dialog.message = ["For example 192.168.1.10:8096 or https://jellyfin.example.com"]
    dialog.buttons = ["Connect", "Cancel"]
    last = JF_RegistryRead("server")
    if last <> "" then dialog.text = last else dialog.text = "http://"
    dialog.observeFieldScoped("buttonSelected", "onAddressDialogButton")
    dialog.observeFieldScoped("wasClosed", "JF_CloseDialog")
    m.top.getScene().dialog = dialog
end sub

sub onAddressDialogButton()
    dialog = m.top.getScene().dialog
    text = dialog.text
    dialog.close = true
    if dialog.buttonSelected = 0 then connect(text)
end sub

' "nas" -> ["http://nas", "http://nas:8096"]; "https://x/jf/" -> ["https://x/jf"]
function serverCandidates(input as String) as Object
    text = input.Trim()
    while Right(text, 1) = "/"
        text = Left(text, Len(text) - 1)
    end while
    if text = "" or text = "http:" or text = "https:" then return []
    lower = LCase(text)
    hasScheme = Left(lower, 7) = "http://" or Left(lower, 8) = "https://"
    if not hasScheme then text = "http://" + text
    for each suffix in ["/web/index.html", "/web"]
        if LCase(Right(text, Len(suffix))) = suffix then text = Left(text, Len(text) - Len(suffix))
    end for
    candidates = [text]
    ' No scheme and no port: Jellyfin's default port is worth a try
    hostPart = Mid(text, 8)
    slash = Instr(1, hostPart, "/")
    if slash > 0 then hostPart = Left(hostPart, slash - 1)
    if not hasScheme and Instr(1, hostPart, ":") = 0
        path = ""
        if slash > 0 then path = Mid(Mid(text, 8), slash)
        candidates.Push("http://" + hostPart + ":8096" + path)
    end if
    return candidates
end function

sub connect(address as String)
    m.candidates = serverCandidates(address)
    if m.candidates.Count() = 0
        m.status.text = "That doesn't look like a server address."
        return
    end if
    m.busy = true
    m.spinner.visible = true
    m.spinner.control = "start"
    tryNextCandidate()
end sub

sub tryNextCandidate()
    candidate = m.candidates.Shift()
    m.current = candidate
    m.status.text = "Connecting to " + candidate + "…"
    task = CreateObject("roSGNode", "ApiTask")
    task.request = { method: "GET", path: "/System/Info/Public", baseUrl: candidate, timeoutMs: 8000 }
    task.observeField("response", "onProbe")
    task.control = "run"
    m.probe = task
end sub

sub onProbe()
    response = m.probe.response
    if response.ok and response.json <> invalid and response.json.Id <> invalid
        m.global.server = m.current
        JF_RegistryWrite("server", m.current)
        JF_ClearSession()
        stopBusy()
        m.top.navigate = { screen: "LoginScreen", params: { serverName: response.json.ServerName }, reset: true }
    else if m.candidates.Count() > 0
        tryNextCandidate()
    else
        stopBusy()
        reason = response.error
        if response.ok then reason = "it isn't a Jellyfin server"
        m.status.text = "Couldn't connect to " + m.current + ": " + reason
    end if
end sub

sub stopBusy()
    m.busy = false
    m.spinner.control = "stop"
    m.spinner.visible = false
end sub
