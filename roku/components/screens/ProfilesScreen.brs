sub init()
    m.grid = m.top.findNode("grid")
    m.actions = m.top.findNode("actions")
    m.status = m.top.findNode("status")
    m.spinner = m.top.findNode("spinner")
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.focusTarget = m.grid

    content = CreateObject("roSGNode", "ContentNode")
    signOut = content.createChild("ContentNode")
    signOut.title = "Sign out"
    m.actions.content = content
    m.actions.observeField("itemSelected", "onSignOut")
    m.grid.observeField("itemSelected", "onProfileSelected")

    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("params", "load")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusTarget.setFocus(true)
end sub

sub load()
    m.spinner.visible = true
    m.spinner.control = "start"
    JF_Get("/JellyFlix/Profiles", invalid, "onHousehold")
end sub

sub onHousehold(event as Object)
    m.spinner.control = "stop"
    m.spinner.visible = false
    response = event.getRoSGNode().response

    if response.code = 401
        ' The session was signed out on the server
        JF_ClearSession()
        m.top.navigate = { screen: "LoginScreen", reset: true }
        return
    end if
    if not response.ok or response.json = invalid
        ' No JellyFlix plugin (or an old one): no profiles, straight to home
        m.top.navigate = { screen: "HomeScreen", reset: true }
        return
    end if

    m.household = response.json
    profiles = m.household.Profiles
    if profiles = invalid or profiles.Count() = 0
        m.top.navigate = { screen: "HomeScreen", reset: true }
        return
    end if
    ' One profile and nothing to choose: skip the question
    if profiles.Count() = 1 and not JF_IsTrue(profiles[0].HasPin) and JF_NormalizeId(profiles[0].Id) = JF_NormalizeId(m.household.CurrentProfileId)
        m.top.navigate = { screen: "HomeScreen", reset: true }
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    for each profile in profiles
        node = content.createChild("ContentNode")
        node.addFields({
            profileId: profile.Id,
            avatarColor: JF_HexColor(profile.AvatarColor),
            isKids: JF_IsTrue(profile.IsKids),
            hasPin: JF_IsTrue(profile.HasPin)
        })
        node.title = profile.Name
        node.HDPosterUrl = JF_UserImageUrl(profile.Id, profile.PrimaryImageTag, 220)
    end for
    count = profiles.Count()
    columns = count
    if columns > 5 then columns = 5
    m.grid.numColumns = columns
    m.grid.numRows = Int((count + columns - 1) / columns)
    width = columns * 220 + (columns - 1) * 50
    m.grid.translation = [(1920 - width) / 2, 400]
    m.grid.content = content

    ' Start on the current profile
    for i = 0 to count - 1
        if JF_NormalizeId(profiles[i].Id) = JF_NormalizeId(m.household.CurrentProfileId) then m.grid.jumpToItem = i
    end for
    m.focusTarget = m.grid
    m.grid.setFocus(true)
end sub

sub onProfileSelected()
    profile = m.household.Profiles[m.grid.itemSelected]
    m.selected = profile
    if JF_IsTrue(profile.HasPin)
        askPin()
    else
        switchTo(invalid)
    end if
end sub

sub askPin()
    dialog = CreateObject("roSGNode", "StandardPinPadDialog")
    dialog.title = "Enter " + m.selected.Name + "'s PIN"
    dialog.buttons = ["OK", "Cancel"]
    dialog.pinPad.pinLength = 4
    dialog.pinPad.secureMode = true
    dialog.observeFieldScoped("buttonSelected", "onPin")
    dialog.observeFieldScoped("wasClosed", "JF_CloseDialog")
    m.top.getScene().dialog = dialog
end sub

sub onPin()
    dialog = m.top.getScene().dialog
    dialog.close = true
    if dialog.buttonSelected = 0 and Len(dialog.pin) = 4 then switchTo(dialog.pin)
end sub

sub switchTo(pin as Dynamic)
    m.status.text = ""
    ' Already signed in as this profile (and no PIN to check)
    if pin = invalid and JF_NormalizeId(m.selected.Id) = JF_NormalizeId(m.household.CurrentProfileId) and JF_NormalizeId(m.selected.Id) = JF_NormalizeId(m.global.userId)
        m.top.navigate = { screen: "HomeScreen", reset: true }
        return
    end if
    body = {}
    if pin <> invalid then body.Pin = pin
    JF_Post("/JellyFlix/Profiles/" + m.selected.Id + "/Switch", body, "onSwitched")
end sub

sub onSwitched(event as Object)
    response = event.getRoSGNode().response
    if response.ok and response.json <> invalid and response.json.AccessToken <> invalid
        JF_SaveSession(response.json)
        m.top.navigate = { screen: "HomeScreen", reset: true }
    else
        message = response.error
        if response.code = 403 or response.code = 401 then message = "That PIN isn't right. " + message
        JF_ShowMessage("Couldn't switch profile", message)
    end if
end sub

sub onSignOut()
    JF_Post("/Sessions/Logout", invalid, "onLoggedOut")
end sub

sub onLoggedOut()
    JF_ClearSession()
    m.top.navigate = { screen: "LoginScreen", reset: true }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "down" and m.grid.hasFocus()
        m.focusTarget = m.actions
        m.actions.setFocus(true)
        return true
    else if key = "up" and m.actions.hasFocus()
        m.focusTarget = m.grid
        m.grid.setFocus(true)
        return true
    end if
    return false
end function
