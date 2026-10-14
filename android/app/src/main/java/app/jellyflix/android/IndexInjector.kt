package app.jellyflix.android

import android.content.Context
import android.webkit.WebResourceResponse
import java.io.ByteArrayInputStream
import java.net.URI
import java.net.HttpURLConnection
import java.net.URL

/**
 * Serves the server's `/web/index.html` with the platform adapter and NativeShell inlined at the top of `<head>`, so
 * `window.NativeShell` exists before the web client's own scripts run. Everything else loads straight from the server.
 */
class IndexInjector(context: Context) {
    private val scripts: String by lazy {
        val assets = context.assets
        listOf("jellyflix/platform.js", "jellyflix/nativeshell.js").joinToString("") { path ->
            val source = assets.open(path).bufferedReader().use { it.readText() }
            // A literal "</script>" inside the inlined code would end the tag early
            "<script>\n${source.replace("</script", "<\\/script")}\n</script>"
        }
    }

    /** True for the web client's start page on [base] (`/web`, `/web/`, `/web/index.html`). */
    fun isIndex(base: String, url: String): Boolean {
        if (!ServerAddress.sameOrigin(base, url)) return false
        return try {
            val basePath = URI(base).rawPath.orEmpty().trimEnd('/')
            val path = URI(url).rawPath.orEmpty().trimEnd('/')
            path == "$basePath/web" || path == "$basePath/web/index.html"
        } catch (e: Exception) {
            false
        }
    }

    /** Fetches the index page and injects the scripts; null lets the WebView load it as usual (and show the error). */
    fun fetch(url: String, userAgent: String): WebResourceResponse? = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 10_000
        connection.readTimeout = 15_000
        connection.setRequestProperty("User-Agent", userAgent)
        connection.setRequestProperty("Accept", "text/html")
        try {
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                null
            } else {
                val html = connection.inputStream.bufferedReader().use { it.readText() }
                val body = inject(html, scripts).toByteArray(Charsets.UTF_8)
                WebResourceResponse("text/html", "utf-8", 200, "OK", mapOf("Cache-Control" to "no-cache"), ByteArrayInputStream(body))
            }
        } finally {
            connection.disconnect()
        }
    } catch (e: Exception) {
        null
    }

    companion object {
        private val HEAD = Regex("<head[^>]*>", RegexOption.IGNORE_CASE)

        fun inject(html: String, scripts: String): String {
            val match = HEAD.find(html) ?: return scripts + html
            return html.substring(0, match.range.last + 1) + scripts + html.substring(match.range.last + 1)
        }
    }
}
