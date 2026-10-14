package app.jellyflix.android

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** A Jellyfin server that answered `/System/Info/Public`. */
data class ServerInfo(val baseUrl: String, val id: String, val name: String, val version: String)

/** Checks that an address is a Jellyfin server. Blocking; call it off the main thread. */
object ServerProbe {
    fun probe(baseUrl: String, timeoutMs: Int = 5000): ServerInfo {
        val connection = URL("$baseUrl/System/Info/Public").openConnection() as HttpURLConnection
        connection.connectTimeout = timeoutMs
        connection.readTimeout = timeoutMs
        connection.setRequestProperty("Accept", "application/json")
        try {
            val code = connection.responseCode
            if (code != HttpURLConnection.HTTP_OK) throw IllegalStateException("HTTP $code")
            val json = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
            val id = json.optString("Id")
            if (id.isEmpty()) throw IllegalStateException("not a Jellyfin server")
            // Servers behind a reverse proxy redirect; keep the address the server actually answered on
            val answered = connection.url.toString().removeSuffix("/System/Info/Public")
            return ServerInfo(answered, id, json.optString("ServerName", "Jellyfin"), json.optString("Version"))
        } finally {
            connection.disconnect()
        }
    }

    /** Tries each candidate for [input] in turn and returns the first server that answers. */
    fun find(input: String): ServerInfo {
        val candidates = ServerAddress.candidates(input)
        if (candidates.isEmpty()) throw IllegalArgumentException("\"$input\" isn't a server address")
        var lastError: Exception? = null
        for (candidate in candidates) {
            try {
                return probe(candidate)
            } catch (e: Exception) {
                lastError = e
            }
        }
        throw lastError!!
    }
}
