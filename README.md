<p align="center"><img alt="JellyFlix" src="webos/splash.png" width="480"/></p>

# JellyFlix clients

TV and device apps for [JellyFlix](https://github.com/yourmomsbasement/JellyFlix-Web), the Netflix-style Jellyfin.
They work with a Jellyfin server that has the [JellyFlix plugin](https://github.com/yourmomsbasement/JellyFlix-Plugin)
installed. Without the plugin you still get a working Jellyfin client, just without profiles and recommendations.

| Platform | Folder | How it works | Output |
| --- | --- | --- | --- |
| **Roku** | [`roku/`](roku) | A native SceneGraph/BrightScript channel that talks to the Jellyfin and JellyFlix plugin APIs directly | `jellyflix-roku-<version>.zip` (sideload or submit) |
| **Android TV, Google TV, Fire TV** (and phones and tablets) | [`android/`](android) | A WebView app that loads the JellyFlix web client **from your server**, with NativeShell injected | APK |
| **LG webOS** | [`webos/`](webos) | Packages the JellyFlix web client release with a webOS NativeShell | `.ipk` |
| **Samsung Tizen** | [`tizen/`](tizen) | Packages the JellyFlix web client release with a Tizen NativeShell | `.wgt` (signed with your Samsung certificate) |

## Why two approaches

The JellyFlix web client already has a TV mode built for remotes. Anything that can run a modern browser engine
reuses it. Roku can't run HTML, so it gets its own native app.

- **Android / Fire TV** loads `http(s)://<server>/web/` in a WebView. The JellyFlix plugin keeps that client up to
  date, so the app picks up new web releases without an update. The app inlines
  [`shared/nativeshell.js`](shared/nativeshell.js) into the server's `index.html`. The web client then knows it's on a TV
  (TV layout, remote Back, exit), what the device decodes (HEVC, HDR10, Dolby Vision, DTS, TrueHD from `MediaCodecList`
  and the display's HDR capabilities) and the device's name. The same APK has a Leanback launcher banner for
  Android TV / Google TV and installs on Fire TV.
- **webOS and Tizen** bundle a [JellyFlix-Web release](https://github.com/yourmomsbasement/JellyFlix-Web/releases)
  (`jellyflix-web.zip`, checked against its SHA-256) into the app and load the platform adapter and NativeShell before
  the client. This is the same model as the official Jellyfin Tizen app. It gives the client full access to the TV's
  APIs: Tizen remote keys and Samsung's product/AV info, and webOS Luna for the model name and HDR / Dolby Vision
  support. Rebuild the app to ship a newer web client; CI can do this for you.
- **Roku** is a native channel covering:
  - LAN server discovery and connecting to a server
  - Quick Connect and password sign-in
  - "Who's watching?" with PINs
  - Home: a hero for the focused title over rows (Continue Watching, Next Up, Top Picks, My List, New, Because you watched…, Top Rated)
  - Per-profile artwork
  - Title pages with match %, Play/Resume, My List and More Like This
  - Episodes, My List and search (including the plugin's "Matches your description")
  - Playback through a device profile built from what the Roku and TV support, progress reporting, a fallback to transcoding, and next-episode autoplay
  - A side menu and deep links

## Building

You need Node.js 20+ for everything, `zip`/`unzip`, and JDK 17 for Android. Run `npm ci` once.

```sh
npm run check            # Roku lint (BrighterScript) + build-script and Roku helper tests

npm run build:roku       # → dist/jellyflix-roku-<version>.zip
npm run package:webos    # → dist/com.jellyflix.app_<version>_all.ipk   (downloads the latest JellyFlix web release)
npm run build:tizen      # → build/tizen/app                          (then sign, see below)
cd android && ./gradlew assembleRelease   # → android/app/build/outputs/apk/release/
```

`node scripts/package-web.mjs <webos|tizen>` takes `--tag web-2026.10.14.14` for a specific web release,
`--zip path/to/jellyflix-web.zip` for a local web build, or `--skip-fetch` to reuse the last download.

The version of every client comes from `package.json`.

### CI

[`.github/workflows/build.yml`](.github/workflows/build.yml) lints and tests, then builds all four platforms on every
push and pull request and uploads the results as artifacts. Pushing a `v*` tag publishes them as a GitHub release.
To get a signed Android release, add these secrets:

- `JELLYFLIX_KEYSTORE_BASE64`
- `JELLYFLIX_KEYSTORE_PASSWORD`
- `JELLYFLIX_KEY_ALIAS`
- `JELLYFLIX_KEY_PASSWORD`

## Installing

- **Roku:** enable developer mode (Home ×3, Up ×2, Right, Left, Right, Left, Right). Open `http://<roku-ip>` and
  upload `jellyflix-roku-<version>.zip` in the Development Application Installer.
- **Android TV / Google TV:** `adb install JellyFlix-release.apk`, or sideload with a file manager.
- **Fire TV:** turn on *Developer options → Install unknown apps*, then `adb connect <fire-tv-ip>` and `adb install …`,
  or use Downloader.
- **LG webOS:** turn on Developer Mode (LG's Developer Mode app). Then run
  `npx ares-setup-device` and `npx ares-install -d <tv> dist/com.jellyflix.app_*.ipk`.
- **Samsung Tizen:** install Tizen Studio with the TV extensions and create a Samsung certificate. Then run
  `tizen build-web -- build/tizen/app`, `tizen package -t wgt -s <profile> -- build/tizen/app/.buildResult`, and
  `tizen install -n JellyFlix.wgt -t <tv>`.

On first launch each app asks for your server. It looks for servers on the local network and also accepts an
address typed in, e.g. `192.168.1.10:8096` or `https://jellyfin.example.com`.

## Layout

| Path | What |
| --- | --- |
| `shared/nativeshell.js` | The `window.NativeShell` jellyfin-web expects, built from a small per-platform adapter (`window.JellyFlixPlatform`) |
| `webos/`, `tizen/` | Manifests, icons and each platform's adapter (`jellyflix-platform.js`) |
| `android/` | Kotlin app: `MainActivity` (WebView, Back handling, index injection), `ConnectActivity` (server picker), `NativeBridge` (JS ↔ Android), `DeviceCapabilities`, `ServerDiscovery` |
| `roku/source/main.brs` | Channel entry point and deep links |
| `roku/components/MainScene.*` | Screen stack and navigation |
| `roku/components/screens/` | Connect, Login, Profiles, Home, Details, Episodes, Grid (My List), Search, Player |
| `roku/components/common/` | Shared helpers (`Utils.brs`) and the Roku device profile (`DeviceProfile.brs`) |
| `roku/components/tasks/` | HTTP (`ApiTask`) and UDP server discovery (`DiscoveryTask`) |
| `scripts/` | Build scripts (`fetch-web`, `package-web`, `package-roku`, `make-icons.sh`) and their tests |

## Status

What has been verified:

- **Roku:** the channel compiles cleanly with BrighterScript. Its helper functions pass tests in a BrightScript
  interpreter.
- **webOS and Tizen:** both packages build from the real JellyFlix web release. In Chromium with a TV user agent, they
  boot into the TV layout with NativeShell active.
- **Android:** the address-parsing tests pass on the JVM. The APK itself is built only by CI, because the Android SDK
  wasn't available where this was written.

None of the apps has run on a real device yet. Before publishing to a store, check:

- remote-key edge cases on each platform
- Roku `StandardKeyboardDialog` and `StandardPinPadDialog`, which need Roku OS 11+
- the webOS `requiredACG` entries for LG's submission check
- direct play of HDR and Dolby Vision files on each device

Not yet built: the end-credit companion on Roku, requests through Seerr on Roku, Android TV home-screen channels
(Watch Next), and an ExoPlayer-based player on Android.
