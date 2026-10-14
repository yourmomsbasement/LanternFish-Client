// Builds the webOS or Tizen app: the JellyFlix web client with the platform adapter and NativeShell loaded first.
//
//   node scripts/package-web.mjs webos [--tag web-…] [--zip local.zip] [--skip-fetch]
//   node scripts/package-web.mjs tizen
//
// Output: build/<platform>/app, ready for `ares-package` (webOS) or `tizen build-web` + `tizen package` (Tizen).
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { fetchWeb, WEB_DIR } from './fetch-web.mjs';
import { BUILD, clean, copy, exists, parseArgs, readJson, ROOT, writeText } from './lib.mjs';

const PLATFORMS = {
    webos: {
        manifest: 'appinfo.json',
        // webOS gives packaged apps PalmSystem; nothing else needs loading
        head: [],
        files: ['appinfo.json', 'icon.png', 'largeIcon.png', 'splash.png']
    },
    tizen: {
        manifest: 'config.xml',
        // Samsung's Product/AV info APIs, provided by the TV at this path
        head: ['<script src="$WEBAPIS/webapis/webapis.js"></script>'],
        files: ['config.xml', 'icon.png']
    }
};

/** Puts `tags` right after `<head>` so NativeShell exists before any of the web client's own scripts run. */
export function injectIntoHead(html, tags) {
    const match = /<head[^>]*>/i.exec(html);
    if (!match) {
        throw new Error('index.html has no <head>');
    }
    const at = match.index + match[0].length;
    return html.slice(0, at) + '\n    ' + tags.join('\n    ') + html.slice(at);
}

/** Fills `{{version}}`-style placeholders in a manifest. */
export function fillTemplate(text, values) {
    return text.replace(/\{\{(\w+)\}\}/g, (whole, key) => (key in values ? String(values[key]) : whole));
}

export async function packageWeb(platformName, options = {}) {
    const platform = PLATFORMS[platformName];
    if (!platform) {
        throw new Error(`Unknown platform "${platformName}"; expected one of ${Object.keys(PLATFORMS).join(', ')}`);
    }

    if (!options.skipFetch || !(await exists(join(WEB_DIR, 'index.html')))) {
        await fetchWeb(options);
    }

    const { version } = await readJson(join(ROOT, 'package.json'));
    const source = join(ROOT, platformName);
    const out = join(BUILD, platformName, 'app');
    await clean(out);

    // The web client itself
    for (const entry of await readdir(WEB_DIR)) {
        // Service workers can't register from file:// or app:// origins; leave them out
        if (entry.startsWith('serviceworker')) continue;
        await copy(join(WEB_DIR, entry), join(out, entry));
    }

    // Platform manifest and icons
    for (const file of platform.files) {
        const from = join(source, file);
        if (file === platform.manifest) {
            await writeText(join(out, file), fillTemplate(await readFile(from, 'utf8'), { version }));
        } else {
            await copy(from, join(out, file));
        }
    }

    // NativeShell: the platform adapter first, then the shared shell that reads it
    await copy(join(source, 'jellyflix-platform.js'), join(out, 'jellyflix', 'platform.js'));
    await copy(join(ROOT, 'shared', 'nativeshell.js'), join(out, 'jellyflix', 'nativeshell.js'));
    const platformJs = await readFile(join(out, 'jellyflix', 'platform.js'), 'utf8');
    await writeText(join(out, 'jellyflix', 'platform.js'), fillTemplate(platformJs, { version }));

    const indexPath = join(out, 'index.html');
    const html = await readFile(indexPath, 'utf8');
    await writeText(indexPath, injectIntoHead(html, [
        ...platform.head,
        '<script src="jellyflix/platform.js"></script>',
        '<script src="jellyflix/nativeshell.js"></script>'
    ]));

    console.log(`JellyFlix for ${platformName} ${version} built in ${out}`);
    return out;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
    const args = parseArgs(process.argv.slice(2));
    packageWeb(args._[0], { repo: args.repo, tag: args.tag, zip: args.zip, skipFetch: !!args['skip-fetch'] })
        .catch((err) => {
            console.error(err.message);
            process.exit(1);
        });
}
