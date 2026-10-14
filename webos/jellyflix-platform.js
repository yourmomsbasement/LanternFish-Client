/*
 * JellyFlix for LG webOS: the platform adapter read by shared/nativeshell.js.
 *
 * appinfo.json sets disableBackHistoryAPI, so the Back key (461) reaches the web client, which steps back through its
 * own pages and asks to exit from the home screen.
 */
(function () {
    'use strict';

    var ua = navigator.userAgent;

    // webOS doesn't name its version in the user agent; its Chromium version does. See LG's webOS TV specifications.
    function webOSVersion() {
        var chrome = /Chrome\/(\d+)/.exec(ua);
        var major = chrome ? parseInt(chrome[1], 10) : 0;
        if (major >= 120) return 25;
        if (major >= 108) return 24;
        if (major >= 94) return 23;
        if (major >= 87) return 22;
        if (major >= 79) return 6;
        if (major >= 68) return 5;
        if (major >= 53) return 4;
        if (/Safari\/538/.test(ua)) return 3;
        return 1;
    }

    var version = webOSVersion();
    var config = {};

    // Luna calls through PalmServiceBridge, which webOS gives every packaged web app
    function luna(uri, params, done) {
        if (typeof window.PalmServiceBridge !== 'function') {
            done(null);
            return;
        }
        try {
            var bridge = new window.PalmServiceBridge();
            bridge.onservicecallback = function (message) {
                try {
                    done(JSON.parse(message));
                } catch (err) {
                    done(null);
                }
            };
            bridge.call(uri, JSON.stringify(params || {}));
        } catch (err) {
            done(null);
        }
    }

    // Ask the TV what it can show before the first device profile is built (a few ms; the web client starts later)
    luna('luna://com.webos.service.config/getConfigs', {
        configNames: ['tv.model.supportHDR', 'tv.model.supportDolbyHDRContents', 'tv.model.modelName', 'tv.config.supportDolbyAtmos']
    }, function (result) {
        if (result && result.configs) config = result.configs;
    });

    window.JellyFlixPlatform = {
        name: 'webOS',
        appVersion: '{{version}}',
        layout: 'tv',
        features: [],
        deviceName: function () {
            var model = config['tv.model.modelName'];
            return model ? 'LG ' + model : 'LG webOS TV';
        },
        profileOptions: function () {
            var hdr = config['tv.model.supportHDR'];
            return {
                // HEVC and 4K from webOS 4 (2018) on
                supportsHevc: version >= 4,
                supportsHdr10: hdr === undefined ? version >= 4 : !!hdr,
                supportsDolbyVision: !!config['tv.model.supportDolbyHDRContents'],
                supportsTrueHd: false,
                supportsDts: version >= 23,
                audioChannels: 6
            };
        },
        screen: function () {
            // The web app renders at 1920x1080 even on 4K panels; ask for 4K video where the TV decodes it
            return version >= 4 ? { width: 3840, height: 2160 } : { width: 1920, height: 1080 };
        },
        exit: function () {
            if (window.webOS && typeof window.webOS.platformBack === 'function') {
                window.webOS.platformBack();
            } else if (window.PalmSystem && typeof window.PalmSystem.platformBack === 'function') {
                window.PalmSystem.platformBack();
            } else {
                window.close();
            }
        },
        openUrl: function (url) {
            luna('luna://com.webos.applicationManager/launch', { id: 'com.webos.app.browser', params: { target: url } }, function () {});
        }
    };
})();
