package app.jellyflix.android

import android.content.Context

/** The server this device connects to. One server at a time; the web client keeps its own sign-in per server. */
class ServerStore(context: Context) {
    private val prefs = context.getSharedPreferences("jellyflix", Context.MODE_PRIVATE)

    var address: String?
        get() = prefs.getString(KEY_ADDRESS, null)
        set(value) = prefs.edit().putString(KEY_ADDRESS, value).apply()

    private companion object {
        const val KEY_ADDRESS = "server_address"
    }
}
