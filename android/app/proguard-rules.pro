# Methods called from JavaScript through addJavascriptInterface
-keepclassmembers class app.lanternfish.NativeBridge {
    @android.webkit.JavascriptInterface <methods>;
}
