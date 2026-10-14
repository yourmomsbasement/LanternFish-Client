package app.lanternfish

import android.content.Context
import android.net.wifi.WifiManager
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException

/** A server that answered Jellyfin's UDP discovery, in the shape the web client's `NativeShell.findServers` expects. */
data class DiscoveredServer(val id: String, val name: String, val address: String, val endpointAddress: String?) {
    fun toJson(): JSONObject = JSONObject()
        .put("Id", id)
        .put("Name", name)
        .put("Address", address)
        .put("EndpointAddress", endpointAddress ?: JSONObject.NULL)
}

/** Jellyfin answers "who is JellyfinServer?" broadcast to UDP port 7359. Blocking; call it off the main thread. */
class ServerDiscovery(private val context: Context) {
    fun discover(timeoutMs: Int = 2500): List<DiscoveredServer> {
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        // Many devices drop incoming broadcast replies on Wi-Fi without a multicast lock
        val lock = wifi?.createMulticastLock("lanternfish-discovery")?.apply {
            setReferenceCounted(false)
            acquire()
        }
        val found = linkedMapOf<String, DiscoveredServer>()
        try {
            DatagramSocket().use { socket ->
                socket.broadcast = true
                socket.soTimeout = 250
                val message = "who is JellyfinServer?".toByteArray()
                socket.send(DatagramPacket(message, message.size, InetAddress.getByName("255.255.255.255"), PORT))

                val buffer = ByteArray(4096)
                val deadline = System.currentTimeMillis() + timeoutMs
                while (System.currentTimeMillis() < deadline) {
                    val packet = DatagramPacket(buffer, buffer.size)
                    try {
                        socket.receive(packet)
                    } catch (e: SocketTimeoutException) {
                        continue
                    }
                    parse(String(packet.data, 0, packet.length))?.let { found.putIfAbsent(it.id, it) }
                }
            }
        } catch (e: Exception) {
            // No network, or broadcasts blocked: nothing found
        } finally {
            lock?.release()
        }
        return found.values.toList()
    }

    private fun parse(reply: String): DiscoveredServer? = try {
        val json = JSONObject(reply)
        val id = json.getString("Id")
        val address = json.getString("Address").trimEnd('/')
        DiscoveredServer(id, json.optString("Name", address), address, json.optString("EndpointAddress").ifEmpty { null })
    } catch (e: Exception) {
        null
    }

    private companion object {
        const val PORT = 7359
    }
}
