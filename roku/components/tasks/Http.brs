' HTTP for tasks: the Jellyfin authorization header and a JSON request helper.

' MediaBrowser Client="JellyFlix for Roku", Device="Living Room", DeviceId="…", Version="0.1.0", Token="…"
function Http_AuthHeader() as String
    header = "MediaBrowser Client=" + Chr(34) + "JellyFlix for Roku" + Chr(34)
    header = header + ", Device=" + Chr(34) + Http_Quote(m.global.deviceName) + Chr(34)
    header = header + ", DeviceId=" + Chr(34) + m.global.deviceId + Chr(34)
    header = header + ", Version=" + Chr(34) + m.global.appVersion + Chr(34)
    if m.global.token <> invalid and m.global.token <> ""
        header = header + ", Token=" + Chr(34) + m.global.token + Chr(34)
    end if
    return header
end function

function Http_Quote(value as String) as String
    return value.Replace(Chr(34), "'")
end function

function Http_QueryString(transfer as Object, query as Dynamic) as String
    if query = invalid then return ""
    parts = []
    for each key in query
        value = query[key]
        if value <> invalid
            if type(value) = "roBoolean" or type(value) = "Boolean"
                if value then value = "true" else value = "false"
            end if
            parts.Push(key + "=" + transfer.Escape(value.ToStr()))
        end if
    end for
    if parts.Count() = 0 then return ""
    text = "?"
    for i = 0 to parts.Count() - 1
        if i > 0 then text = text + "&"
        text = text + parts[i]
    end for
    return text
end function

' Performs [request] and returns { ok, code, json, error }
function Http_Send(request as Object) as Object
    baseUrl = request.baseUrl
    if baseUrl = invalid or baseUrl = "" then baseUrl = m.global.server
    method = request.method
    if method = invalid then method = "GET"
    timeoutMs = request.timeoutMs
    if timeoutMs = invalid then timeoutMs = 20000

    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnablePeerVerification(true)
    transfer.EnableHostVerification(true)
    transfer.RetainBodyOnError(true)
    transfer.SetUrl(baseUrl + request.path + Http_QueryString(transfer, request.query))
    transfer.AddHeader("Authorization", Http_AuthHeader())
    transfer.AddHeader("Accept", "application/json")
    transfer.SetRequest(method)

    if method = "GET"
        started = transfer.AsyncGetToString()
    else
        payload = ""
        if request.body <> invalid
            transfer.AddHeader("Content-Type", "application/json")
            payload = FormatJson(request.body)
        end if
        started = transfer.AsyncPostFromString(payload)
    end if
    if not started then return { ok: false, code: 0, json: invalid, error: "Couldn't start the request" }

    msg = wait(timeoutMs, port)
    if type(msg) <> "roUrlEvent"
        transfer.AsyncCancel()
        return { ok: false, code: 0, json: invalid, error: "The server didn't answer in time" }
    end if

    code = msg.GetResponseCode()
    body = msg.GetString()
    json = invalid
    if body <> invalid and body <> "" then json = ParseJson(body)
    result = { ok: code >= 200 and code < 300, code: code, json: json, error: "" }
    if not result.ok
        if code < 0
            result.error = msg.GetFailureReason()
        else if json <> invalid and json.Message <> invalid
            result.error = json.Message
        else
            result.error = "HTTP " + code.ToStr()
        end if
    end if
    return result
end function
