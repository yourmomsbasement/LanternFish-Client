/*
 * JellyFlix NativeShell
 *
 * The JellyFlix web client (a jellyfin-web fork) asks `window.NativeShell` for everything a host app knows better
 * than a browser: the device's name and id, which layout to start in, which features exist, what the device can play
 * and how to leave the app. This file builds that object from a small platform adapter, `window.JellyFlixPlatform`,
 * which each client (webOS, Tizen, Android) defines in a script loaded before this one.
 *
 * Adapter shape (every member is optional unless noted):
 *   name            (required) e.g. 'webOS'; shown in the server's device list as "JellyFlix for <name>"
 *   appVersion      the client's own version
 *   deviceName()    a friendly device name, e.g. "LG OLED65C3"
 *   deviceId()      a stable id; one is generated and stored when missing
 *   layout          'tv' | 'mobile' | 'desktop'; defaults to 'tv'
 *   features        extra AppFeature names this host supports
 *   profileOptions()  options passed to the web client's device profile builder (supportsHevc, supportsHdr10, ...)
 *   screen()        { width, height } of the display in physical pixels
 *   exit()          leave the app
 *   openUrl(url)    open a link outside the app
 *   init()          called once when the web client starts (register remote keys, etc.)
 *   selectServer()  show the host's own server picker instead of the web client's
 *   findServers(timeoutMs)  a Promise of servers found on the local network ({ Id, Name, Address, EndpointAddress })
 *   enableFullscreen(), disableFullscreen(), updateMediaSession(info), hideMediaSession()
 */
(function () {
    'use strict';

    var platform = window.JellyFlixPlatform;
    if (!platform) {
        console.error('[JellyFlix] window.JellyFlixPlatform is missing; NativeShell not installed');
        return;
    }

    var DEVICE_ID_KEY = 'jellyflix-device-id';

    // Features every JellyFlix TV client supports. Names match jellyfin-web's AppFeature enum.
    var BASE_FEATURES = [
        'exit',
        'exitmenu',
        'htmlaudioautoplay',
        'htmlvideoautoplay',
        'displaylanguage',
        'displaymode',
        'multiserver',
        'physicalvolumecontrol',
        'remotecontrol',
        'remotevideo',
        'screensaver',
        'subtitleappearancesettings',
        'subtitleburnsettings'
    ];

    function generateId() {
        if (window.crypto && window.crypto.getRandomValues) {
            var bytes = new Uint8Array(16);
            window.crypto.getRandomValues(bytes);
            return Array.prototype.map.call(bytes, function (b) {
                return ('0' + b.toString(16)).slice(-2);
            }).join('');
        }
        return String(Date.now()) + String(Math.random()).slice(2);
    }

    function storedDeviceId() {
        try {
            var id = window.localStorage.getItem(DEVICE_ID_KEY);
            if (!id) {
                id = generateId();
                window.localStorage.setItem(DEVICE_ID_KEY, id);
            }
            return id;
        } catch (err) {
            console.warn('[JellyFlix] localStorage unavailable, device id will not persist', err);
            return generateId();
        }
    }

    function call(name, fallback) {
        var fn = platform[name];
        if (typeof fn !== 'function') return fallback;
        try {
            var value = fn.apply(platform, Array.prototype.slice.call(arguments, 2));
            return value === undefined ? fallback : value;
        } catch (err) {
            console.error('[JellyFlix] platform.' + name + ' failed', err);
            return fallback;
        }
    }

    var cachedDeviceId;
    var features = BASE_FEATURES.concat(platform.features || []).map(function (f) {
        return String(f).toLowerCase();
    });

    var AppHost = {
        init: function () {
            call('init');
            return Promise.resolve({
                deviceId: AppHost.deviceId(),
                deviceName: AppHost.deviceName()
            });
        },
        appName: function () {
            return 'JellyFlix for ' + platform.name;
        },
        appVersion: function () {
            return platform.appVersion || '1.0.0';
        },
        deviceId: function () {
            if (!cachedDeviceId) {
                cachedDeviceId = call('deviceId', null) || storedDeviceId();
            }
            return cachedDeviceId;
        },
        deviceName: function () {
            return call('deviceName', null) || ('JellyFlix ' + platform.name);
        },
        exit: function () {
            if (typeof platform.exit === 'function') {
                call('exit');
            } else {
                window.close();
            }
        },
        supports: function (command) {
            return features.indexOf(String(command).toLowerCase()) !== -1;
        },
        getDefaultLayout: function () {
            return platform.layout || 'tv';
        },
        getDeviceProfile: function (profileBuilder) {
            return profileBuilder(Object.assign({ enableMkvProgressive: false }, call('profileOptions', {})));
        },
        screen: function () {
            return call('screen', null);
        },
        getSyncProfile: function (profileBuilder) {
            return Promise.resolve(profileBuilder({}));
        }
    };

    window.NativeShell = {
        AppHost: AppHost,
        enableFullscreen: function () {
            call('enableFullscreen');
        },
        disableFullscreen: function () {
            call('disableFullscreen');
        },
        openUrl: function (url, target) {
            if (typeof platform.openUrl === 'function') {
                call('openUrl', undefined, url, target);
            } else {
                window.open(url, target || '_blank');
            }
        },
        updateMediaSession: function (mediaInfo) {
            call('updateMediaSession', undefined, mediaInfo);
        },
        hideMediaSession: function () {
            call('hideMediaSession');
        },
        updateVolumeLevel: function (volume) {
            call('updateVolumeLevel', undefined, volume);
        },
        getPlugins: function () {
            return [];
        },
        onLocalUserSignedIn: function (user, accessToken) {
            call('onSignedIn', undefined, user, accessToken);
            return Promise.resolve();
        },
        onLocalUserSignedOut: function (logoutInfo) {
            call('onSignedOut', undefined, logoutInfo);
        }
    };

    // Optional hooks: the web client checks for these by type, so only define the ones the platform has
    if (typeof platform.selectServer === 'function') {
        window.NativeShell.selectServer = function () {
            call('selectServer');
        };
    }
    if (typeof platform.findServers === 'function') {
        window.NativeShell.findServers = function (timeoutMs) {
            return Promise.resolve(call('findServers', [], timeoutMs));
        };
    }

    // Lets the web client and the shells tell a packaged JellyFlix app from a plain browser.
    window.appMode = platform.appMode || 'jellyflix';
})();
