package app.jellyflix.android

import android.annotation.SuppressLint
import android.annotation.TargetApi
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Hosts the JellyFlix web client served by the user's Jellyfin server (the JellyFlix plugin keeps it up to date), with
 * NativeShell injected so the client knows it runs on Android TV, Fire TV or a phone.
 */
class MainActivity : Activity(), NativeBridge.Host {
    private lateinit var store: ServerStore
    private lateinit var capabilities: DeviceCapabilities
    private lateinit var injector: IndexInjector
    private lateinit var webView: WebView
    private lateinit var fullscreenContainer: FrameLayout
    private lateinit var errorPanel: View

    // Read on WebView's network thread in shouldInterceptRequest
    @Volatile private var serverBase: String? = null
    @Volatile private var userAgent: String = ""

    private var customView: View? = null
    private var customViewCallback: WebChromeClient.CustomViewCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = ServerStore(this)
        capabilities = DeviceCapabilities(this)
        injector = IndexInjector(this)

        val server = store.address
        if (server == null) {
            openServerPicker()
            finish()
            return
        }

        setContentView(R.layout.activity_main)
        webView = findViewById(R.id.web)
        fullscreenContainer = findViewById(R.id.fullscreen)
        errorPanel = findViewById(R.id.error)
        findViewById<Button>(R.id.retry).setOnClickListener { load(server) }
        findViewById<Button>(R.id.change_server).setOnClickListener { showServerPicker() }

        setUpWebView()
        if (savedInstanceState == null || webView.restoreState(savedInstanceState) == null) {
            load(server)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // ConnectActivity picked a (possibly different) server
        store.address?.let { load(it) }
    }

    @SuppressLint("SetJavaScriptEnabled", "AddJavascriptInterface")
    private fun setUpWebView() {
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)
        with(webView.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            useWideViewPort = true
            loadWithOverviewMode = true
            // The web client's browser detection turns on TV mode for user agents containing "tv", and treats
            // "Mobile" as a phone; say what this device really is
            var agent = userAgentString
            if (capabilities.isTv) agent = agent.replace(" Mobile", "") + " SmartTV"
            agent += " JellyFlix/${BuildConfig.VERSION_NAME}"
            userAgentString = agent
            userAgent = agent
        }
        webView.isFocusable = true
        webView.isFocusableInTouchMode = true

        val deviceId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
        webView.addJavascriptInterface(NativeBridge(this, capabilities, ServerDiscovery(this), deviceId), "JellyFlixAndroid")
        webView.webViewClient = Client()
        webView.webChromeClient = Chrome()
    }

    private fun load(server: String) {
        serverBase = server
        errorPanel.visibility = View.GONE
        webView.visibility = View.VISIBLE
        webView.loadUrl(ServerAddress.webUrl(server))
        webView.requestFocus()
    }

    private fun showError(message: String) {
        errorPanel.visibility = View.VISIBLE
        findViewById<TextView>(R.id.error_message).text = message
        findViewById<Button>(R.id.retry).requestFocus()
    }

    private inner class Client : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
            val base = serverBase ?: return null
            val url = request.url.toString()
            if (request.method == "GET" && injector.isIndex(base, url)) {
                return injector.fetch(url, userAgent)
            }
            return null
        }

        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            val base = serverBase ?: return false
            val url = request.url.toString()
            if (ServerAddress.sameOrigin(base, url)) return false
            openExternal(url)
            return true
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
            errorPanel.visibility = View.GONE
        }

        @TargetApi(Build.VERSION_CODES.M)
        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            if (request.isForMainFrame) {
                showError(getString(R.string.load_failed, serverBase) + "\n" + error.description)
            }
        }

        // Android 5.1 (Fire OS 5) only has the older callback, which reports main-frame errors only
        @Deprecated("Replaced by the WebResourceRequest overload on API 23")
        override fun onReceivedError(view: WebView, errorCode: Int, description: String?, failingUrl: String?) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                showError(getString(R.string.load_failed, serverBase) + "\n" + description.orEmpty())
            }
        }
    }

    private inner class Chrome : WebChromeClient() {
        // HTML fullscreen (phones and tablets; TV layout plays full screen anyway)
        override fun onShowCustomView(view: View, callback: CustomViewCallback) {
            customView?.let { onHideCustomView() }
            customView = view
            customViewCallback = callback
            fullscreenContainer.addView(view, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            fullscreenContainer.visibility = View.VISIBLE
            setFullscreen(true)
        }

        override fun onHideCustomView() {
            fullscreenContainer.removeAllViews()
            fullscreenContainer.visibility = View.GONE
            customView = null
            customViewCallback?.onCustomViewHidden()
            customViewCallback = null
            setFullscreen(false)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_BACK && ::webView.isInitialized && errorPanel.visibility != View.VISIBLE) {
            if (event.action == KeyEvent.ACTION_UP) handleBack()
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    /**
     * Android delivers Back to the activity, not the page. In TV layout the web client treats Escape as Back (it steps
     * out of dialogs and pages, and asks to exit from home); elsewhere, step back through the WebView's history.
     */
    private fun handleBack() {
        if (customView != null) {
            customViewCallback?.onCustomViewHidden()
            return
        }
        val script = """
            (function () {
                if (!document.documentElement.classList.contains('layout-tv')) return 'history';
                var target = document.activeElement || document.body;
                ['keydown', 'keyup'].forEach(function (type) {
                    target.dispatchEvent(new KeyboardEvent(type, { key: 'Escape', code: 'Escape', bubbles: true, cancelable: true }));
                });
                return 'handled';
            })();
        """.trimIndent()
        webView.evaluateJavascript(script) { result ->
            if (result?.contains("handled") == true) return@evaluateJavascript
            if (webView.canGoBack()) webView.goBack() else finish()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (::webView.isInitialized) webView.saveState(outState)
    }

    override fun onResume() {
        super.onResume()
        if (::webView.isInitialized) webView.onResume()
    }

    override fun onPause() {
        if (::webView.isInitialized) webView.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.removeJavascriptInterface("JellyFlixAndroid")
            webView.destroy()
        }
        super.onDestroy()
    }

    private fun openServerPicker() {
        startActivity(Intent(this, ConnectActivity::class.java))
    }

    // NativeBridge.Host

    override fun exitApp() = finish()

    override fun openExternal(url: String) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (e: ActivityNotFoundException) {
            // TVs often have no browser
            Toast.makeText(this, url, Toast.LENGTH_LONG).show()
        }
    }

    override fun showServerPicker() = openServerPicker()

    override fun setFullscreen(enabled: Boolean) {
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = if (enabled) {
            View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        } else {
            View.SYSTEM_UI_FLAG_VISIBLE
        }
    }

    override fun setPlaying(playing: Boolean) {
        // Keep the screen (and the TV's screensaver) off while something plays
        if (playing) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun evaluate(script: String) {
        if (::webView.isInitialized) webView.evaluateJavascript(script, null)
    }
}
