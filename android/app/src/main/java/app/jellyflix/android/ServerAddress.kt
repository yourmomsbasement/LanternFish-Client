package app.jellyflix.android

import java.net.URI

/** Turns what someone typed ("jelly.local", "192.168.1.10:8096", "https://media.example.com/jellyfin/") into URLs. */
object ServerAddress {
    private const val DEFAULT_PORT = 8096

    /**
     * The addresses worth trying for [input], best first: as typed, then with Jellyfin's default port when no port was
     * given over plain http. Returns base URLs without a trailing slash, or an empty list when [input] isn't an address.
     */
    fun candidates(input: String): List<String> {
        val trimmed = input.trim().trimEnd('/')
        if (trimmed.isEmpty() || trimmed.any { it.isWhitespace() }) return emptyList()

        val hasScheme = trimmed.startsWith("http://", ignoreCase = true) || trimmed.startsWith("https://", ignoreCase = true)
        val withScheme = if (hasScheme) trimmed else "http://$trimmed"
        val uri = try {
            URI(withScheme)
        } catch (e: Exception) {
            return emptyList()
        }
        if (uri.host.isNullOrEmpty()) return emptyList()

        val base = withScheme.removeSuffix("/web/index.html").removeSuffix("/web").trimEnd('/')
        val result = mutableListOf(base)
        if (!hasScheme && uri.port == -1) {
            val path = uri.rawPath.orEmpty().trimEnd('/')
            result.add("http://${uri.host}:$DEFAULT_PORT$path")
        }
        return result.distinct()
    }

    /** The web client's start page for a server base URL. */
    fun webUrl(base: String) = "$base/web/index.html"

    /** True when [url] is on the same server (scheme, host and port) as [base]. */
    fun sameOrigin(base: String, url: String): Boolean = try {
        val a = URI(base)
        val b = URI(url)
        a.scheme.equals(b.scheme, ignoreCase = true) && a.host.equals(b.host, ignoreCase = true) && port(a) == port(b)
    } catch (e: Exception) {
        false
    }

    private fun port(uri: URI) = when {
        uri.port != -1 -> uri.port
        uri.scheme.equals("https", ignoreCase = true) -> 443
        else -> 80
    }
}
