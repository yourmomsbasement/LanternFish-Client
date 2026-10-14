package app.jellyflix.android

import android.webkit.JavascriptInterface
import org.json.JSONArray
import org.json.JSONObject
import kotlin.concurrent.thread

/**
 * `window.JellyFlixAndroid` in the web client. assets/jellyflix/platform.js turns it into the platform adapter that
 * shared/nativeshell.js reads. Methods run on a WebView binder thread; anything touching views goes through [host].
 */
class NativeBridge(
    private val host: Host,
    private val capabilities: DeviceCapabilities,
    private val discovery: ServerDiscovery,
    private val deviceId: String,
) {
    /** What the bridge needs from the activity, always called on the main thread. */
    interface Host {
        fun exitApp()
        fun openExternal(url: String)
        fun showServerPicker()
        fun setFullscreen(enabled: Boolean)
        fun setPlaying(playing: Boolean)
        fun evaluate(script: String)
    }

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private fun onMain(block: Host.() -> Unit) {
        mainHandler.post { host.block() }
    }

    @JavascriptInterface fun platformName(): String = capabilities.platformName

    @JavascriptInterface fun isTv(): Boolean = capabilities.isTv

    @JavascriptInterface fun appVersion(): String = BuildConfig.VERSION_NAME

    @JavascriptInterface fun deviceId(): String = deviceId

    @JavascriptInterface fun deviceName(): String = capabilities.deviceName

    @JavascriptInterface fun profileOptions(): String = capabilities.profileOptions().toString()

    @JavascriptInterface
    fun screen(): String {
        val (width, height) = capabilities.screenSize()
        return JSONObject().put("width", width).put("height", height).toString()
    }

    @JavascriptInterface fun exit() = onMain { exitApp() }

    @JavascriptInterface fun openUrl(url: String) = onMain { openExternal(url) }

    @JavascriptInterface fun selectServer() = onMain { showServerPicker() }

    @JavascriptInterface fun enableFullscreen() = onMain { setFullscreen(true) }

    @JavascriptInterface fun disableFullscreen() = onMain { setFullscreen(false) }

    @JavascriptInterface fun setPlaying(playing: Boolean) = onMain { setPlaying(playing) }

    /** Answers through `window.__jellyflixResolve(callbackId, servers)` once discovery finishes. */
    @JavascriptInterface
    fun findServers(callbackId: Int, timeoutMs: Int) {
        thread(name = "jellyflix-discovery") {
            val servers = JSONArray()
            discovery.discover(timeoutMs.coerceIn(500, 5000)).forEach { servers.put(it.toJson()) }
            val script = "window.__jellyflixResolve && window.__jellyflixResolve($callbackId, $servers);"
            onMain { evaluate(script) }
        }
    }
}
