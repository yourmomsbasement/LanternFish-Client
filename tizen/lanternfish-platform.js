/*
 * Lanternfish for Samsung Tizen: the platform adapter read by shared/nativeshell.js.
 *
 * Remote keys other than the arrows, Enter and Back reach a Tizen app only once registered; the web client already
 * maps the Tizen key codes (10009 Back, 10252 Play/Pause, 412/417 Rewind/Fast forward…).
 */
(function () {
    'use strict';

    var MEDIA_KEYS = [
        'MediaPlayPause', 'MediaPlay', 'MediaPause', 'MediaStop',
        'MediaRewind', 'MediaFastForward', 'MediaTrackPrevious', 'MediaTrackNext',
        'ColorF0Red', 'ColorF1Green', 'ColorF2Yellow', 'ColorF3Blue', 'Info'
    ];

    function webapis(fn, fallback) {
        try {
            return window.webapis ? fn(window.webapis) : fallback;
        } catch (err) {
            return fallback;
        }
    }

    function tizenVersion() {
        var match = /Tizen (\d+)\.(\d+)/i.exec(navigator.userAgent);
        return match ? parseInt(match[1], 10) + parseInt(match[2], 10) / 10 : 0;
    }

    window.LanternfishPlatform = {
        name: 'Tizen',
        appVersion: '{{version}}',
        layout: 'tv',
        features: [],
        init: function () {
            if (!window.tizen || !window.tizen.tvinputdevice) return;
            var supported = window.tizen.tvinputdevice.getSupportedKeys().map(function (key) {
                return key.name;
            });
            var keys = MEDIA_KEYS.filter(function (name) {
                return supported.indexOf(name) !== -1;
            });
            if (window.tizen.tvinputdevice.registerKeyBatch) {
                window.tizen.tvinputdevice.registerKeyBatch(keys);
            } else {
                keys.forEach(function (key) {
                    window.tizen.tvinputdevice.registerKey(key);
                });
            }
        },
        deviceId: function () {
            return webapis(function (w) {
                return w.productinfo.getDuid();
            }, null);
        },
        deviceName: function () {
            var model = webapis(function (w) {
                return w.productinfo.getRealModel() || w.productinfo.getModel();
            }, null);
            return model ? 'Samsung ' + model : 'Samsung Smart TV';
        },
        profileOptions: function () {
            var uhd = webapis(function (w) {
                return w.productinfo.isUdPanelSupported();
            }, tizenVersion() >= 3);
            var hdr = webapis(function (w) {
                return w.avinfo.isHdrTvSupport();
            }, false);
            return {
                supportsHevc: true,
                supportsHdr10: hdr,
                supportsHlg: hdr,
                // Samsung TVs play HDR10+ but not Dolby Vision
                supportsDolbyVision: false,
                supportsDts: tizenVersion() < 4,
                supportsTrueHd: false,
                maxVideoWidth: uhd ? 3840 : 1920,
                audioChannels: 6
            };
        },
        screen: function () {
            var uhd = webapis(function (w) {
                return w.productinfo.isUdPanelSupported();
            }, false);
            return uhd ? { width: 3840, height: 2160 } : { width: 1920, height: 1080 };
        },
        exit: function () {
            window.tizen.application.getCurrentApplication().exit();
        },
        openUrl: function (url) {
            var control = new window.tizen.ApplicationControl('http://tizen.org/appcontrol/operation/view', url);
            window.tizen.application.launchAppControl(control, null, function () {}, function () {});
        }
    };
})();
