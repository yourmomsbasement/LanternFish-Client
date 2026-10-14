# Methods called from JavaScript through addJavascriptInterface
-keepclassmembers class app.jellyflix.android.NativeBridge {
    @android.webkit.JavascriptInterface <methods>;
}
