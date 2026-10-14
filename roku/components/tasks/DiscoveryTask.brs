sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    port = CreateObject("roMessagePort")
    socket = CreateObject("roDatagramSocket")
    socket.setMessagePort(port)
    target = CreateObject("roSocketAddress")
    target.setAddress("255.255.255.255:7359")
    socket.setSendToAddress(target)
    socket.setBroadcast(true)
    socket.notifyReadable(true)
    socket.sendStr("who is JellyfinServer?")

    found = {}
    servers = []
    clock = CreateObject("roTimespan")
    while clock.TotalMilliseconds() < 2500
        msg = wait(250, port)
        if type(msg) = "roSocketEvent" and socket.isReadable()
            reply = ParseJson(socket.receiveStr(4096))
            if reply <> invalid and reply.Id <> invalid and reply.Address <> invalid and found[reply.Id] = invalid
                found[reply.Id] = true
                name = reply.Name
                if name = invalid then name = reply.Address
                servers.Push({ Id: reply.Id, Name: name, Address: reply.Address })
            end if
        end if
    end while
    socket.close()
    m.top.servers = servers
end sub
