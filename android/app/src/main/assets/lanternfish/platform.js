/*
 * Lanternfish for Android TV, Fire TV and Android phones: the platform adapter read by shared/nativeshell.js, backed by
 * the app's `window.LanternfishAndroid` bridge (NativeBridge.kt). Inlined into the server's index.html by the app.
 */
(function () {
    'use strict';

    var bridge = window.LanternfishAndroid;
    if (!bridge) return;

    function json(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (err) {
            return fallback;
        }
    }

    var pending = {};
    var nextCallback = 1;
    window.__lanternfishResolve = function (id, value) {
        var resolve = pending[id];
        delete pending[id];
        if (resolve) resolve(value);
    };

    var tv = bridge.isTv();

    window.LanternfishPlatform = {
        name: bridge.platformName(),
        appVersion: bridge.appVersion(),
        // Phones and tablets get the JellyFlix web client's responsive layout
        layout: tv ? 'tv' : 'modern',
        features: tv ? ['externallinks'] : ['externallinks', 'fullscreenchange'],
        deviceId: function () {
            return bridge.deviceId();
        },
        deviceName: function () {
            return bridge.deviceName();
        },
        profileOptions: function () {
            return json(bridge.profileOptions(), {});
        },
        screen: function () {
            return json(bridge.screen(), null);
        },
        exit: function () {
            bridge.exit();
        },
        openUrl: function (url) {
            bridge.openUrl(String(url));
        },
        selectServer: function () {
            bridge.selectServer();
        },
        findServers: function (timeoutMs) {
            return new Promise(function (resolve) {
                var id = nextCallback++;
                pending[id] = resolve;
                bridge.findServers(id, timeoutMs || 1000);
            });
        },
        enableFullscreen: function () {
            bridge.enableFullscreen();
        },
        disableFullscreen: function () {
            bridge.disableFullscreen();
        },
        updateMediaSession: function () {
            bridge.setPlaying(true);
        },
        hideMediaSession: function () {
            bridge.setPlaying(false);
        }
    };
})();
