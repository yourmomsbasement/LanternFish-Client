package app.jellyflix.android

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.concurrent.thread

/** Picks the Jellyfin server: one typed in, or one found on the local network. Remote- and touch-friendly. */
class ConnectActivity : Activity() {
    private lateinit var store: ServerStore
    private lateinit var address: EditText
    private lateinit var connect: Button
    private lateinit var status: TextView
    private lateinit var servers: LinearLayout
    private val main = Handler(Looper.getMainLooper())
    private var connecting = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_connect)
        store = ServerStore(this)
        address = findViewById(R.id.address)
        connect = findViewById(R.id.connect)
        status = findViewById(R.id.status)
        servers = findViewById(R.id.servers)

        store.address?.let { address.setText(it) }
        connect.setOnClickListener { connectTo(address.text.toString()) }
        address.setOnEditorActionListener { _, actionId, event ->
            val enter = event?.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN
            if (actionId == EditorInfo.IME_ACTION_GO || enter) {
                connectTo(address.text.toString())
                true
            } else {
                false
            }
        }

        discover()
        // On a TV the on-screen keyboard is a detour; start on the Connect button when an address is filled in
        if (address.text.isNotEmpty()) connect.requestFocus() else address.requestFocus()
    }

    private fun discover() {
        status.setText(R.string.connect_searching)
        thread(name = "jellyflix-discovery") {
            val found = ServerDiscovery(this).discover()
            main.post {
                if (isFinishing || connecting) return@post
                servers.removeAllViews()
                if (found.isEmpty()) {
                    status.setText(R.string.connect_none_found)
                    return@post
                }
                status.setText(R.string.connect_found)
                found.forEach { server -> servers.addView(serverButton(server)) }
                if (store.address == null) servers.getChildAt(0)?.requestFocus()
            }
        }
    }

    private fun serverButton(server: DiscoveredServer) = Button(this).apply {
        text = "${server.name}\n${server.address}"
        isAllCaps = false
        setBackgroundResource(R.drawable.button)
        @Suppress("DEPRECATION") // Context.getColorStateList needs API 23
        val textColors = resources.getColorStateList(R.color.button_text)
        setTextColor(textColors)
        val padding = (16 * resources.displayMetrics.density).toInt()
        setPadding(padding * 2, padding / 2, padding * 2, padding / 2)
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = padding / 2
        }
        setOnClickListener { connectTo(server.address) }
    }

    private fun connectTo(input: String) {
        if (connecting) return
        val trimmed = input.trim()
        if (trimmed.isEmpty()) {
            address.requestFocus()
            return
        }
        connecting = true
        connect.isEnabled = false
        status.text = getString(R.string.connect_checking, trimmed)
        thread(name = "jellyflix-connect") {
            val result = runCatching { ServerProbe.find(trimmed) }
            main.post {
                connecting = false
                connect.isEnabled = true
                result.fold(
                    onSuccess = { info ->
                        store.address = info.baseUrl
                        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP))
                        finish()
                    },
                    onFailure = { error ->
                        status.text = getString(R.string.connect_failed, trimmed, error.message ?: error.javaClass.simpleName)
                        address.requestFocus()
                    },
                )
            }
        }
    }
}
