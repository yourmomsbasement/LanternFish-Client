package app.lanternfish

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.MediaCodecList
import android.os.Build
import android.provider.Settings
import android.view.Display
import android.view.WindowManager
import org.json.JSONObject

/** What this device is and what it can decode, for the web client's device profile. */
class DeviceCapabilities(private val context: Context) {

    val isFireTv: Boolean by lazy {
        context.packageManager.hasSystemFeature(FEATURE_FIRE_TV) || Build.MODEL.startsWith("AFT")
    }

    val isTv: Boolean by lazy {
        val uiMode = context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            isFireTv
    }

    val platformName: String
        get() = when {
            isFireTv -> "Fire TV"
            isTv -> "Android TV"
            else -> "Android"
        }

    /** "Living Room SHIELD", "Fire TV Stick 4K Max", or the model when the user never named the device. */
    val deviceName: String by lazy {
        val named = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
        } else {
            null
        }
        named?.takeIf { it.isNotBlank() } ?: "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}"
    }

    private val decoderTypes: Set<String> by lazy {
        try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
                .filter { !it.isEncoder }
                .flatMap { it.supportedTypes.map(String::lowercase) }
                .toSet()
        } catch (e: Exception) {
            emptySet()
        }
    }

    private val display: Display? by lazy {
        @Suppress("DEPRECATION")
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay
    }

    private val hdrTypes: Set<Int> by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            @Suppress("DEPRECATION")
            display?.hdrCapabilities?.supportedHdrTypes?.toSet() ?: emptySet()
        } else {
            emptySet()
        }
    }

    /** The largest mode the display supports, in physical pixels; TVs often run their UI at 1080p on a 4K panel. */
    fun screenSize(): Pair<Int, Int> {
        val display = display ?: return 1920 to 1080
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val largest = display.supportedModes.maxByOrNull { it.physicalWidth * it.physicalHeight }
            if (largest != null) return largest.physicalWidth to largest.physicalHeight
        }
        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)
        return maxOf(metrics.widthPixels, metrics.heightPixels) to minOf(metrics.widthPixels, metrics.heightPixels)
    }

    fun hasDecoder(mime: String) = mime in decoderTypes

    /** Options for jellyfin-web's device profile builder (src/scripts/browserDeviceProfile.js). */
    fun profileOptions(): JSONObject {
        val (width, _) = screenSize()
        return JSONObject()
            .put("supportsHevc", hasDecoder("video/hevc"))
            .put("supportsHdr10", Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && HDR_TYPE_HDR10 in hdrTypes)
            .put("supportsHlg", Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && HDR_TYPE_HLG in hdrTypes)
            .put("supportsDolbyVision", HDR_TYPE_DOLBY_VISION in hdrTypes && hasDecoder("video/dolby-vision"))
            .put("supportsDts", hasDecoder("audio/vnd.dts"))
            .put("supportsTrueHd", hasDecoder("audio/true-hd"))
            .put("maxVideoWidth", width)
            .put("audioChannels", if (isTv) 6 else 2)
    }

    private companion object {
        const val FEATURE_FIRE_TV = "amazon.hardware.fire_tv"
        // Display.HdrCapabilities constants, inlined so they compile against older API levels
        const val HDR_TYPE_DOLBY_VISION = 1
        const val HDR_TYPE_HDR10 = 2
        const val HDR_TYPE_HLG = 3
    }
}
