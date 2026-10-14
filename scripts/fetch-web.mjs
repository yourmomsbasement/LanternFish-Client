// Downloads a JellyFlix web client release (the same build the JellyFlix plugin installs on the server) and unpacks it
// into .cache/web. webOS and Tizen package this build with their NativeShell; Android and Roku don't need it.
//
//   node scripts/fetch-web.mjs                    newest release
//   node scripts/fetch-web.mjs --tag web-2026.10.01.42
//   node scripts/fetch-web.mjs --zip path/to/jellyflix-web.zip   a local build (no checksum)
//   node scripts/fetch-web.mjs --repo owner/JellyFlix-Web
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { CACHE, clean, download, exists, parseArgs, sha256, unzip, writeText } from './lib.mjs';

export const WEB_DIR = join(CACHE, 'web');
const DEFAULT_REPO = 'yourmomsbasement/JellyFlix-Web';

export function releaseUrl(repo, tag, asset) {
    return tag
        ? `https://github.com/${repo}/releases/download/${tag}/${asset}`
        : `https://github.com/${repo}/releases/latest/download/${asset}`;
}

export async function fetchWeb({ repo = DEFAULT_REPO, tag, zip } = {}) {
    const zipPath = join(CACHE, 'jellyflix-web.zip');
    let release = { version: 'local', source: zip };

    if (zip) {
        await writeText(zipPath, await readFile(zip));
    } else {
        console.log(`Downloading JellyFlix web ${tag || 'latest'} from ${repo}`);
        const [archive, checksum, info] = await Promise.all([
            download(releaseUrl(repo, tag, 'jellyflix-web.zip')),
            download(releaseUrl(repo, tag, 'jellyflix-web.zip.sha256')),
            download(releaseUrl(repo, tag, 'release.json'))
        ]);
        const expected = checksum.toString('utf8').trim().split(/\s+/)[0].toLowerCase();
        const actual = sha256(archive);
        if (expected !== actual) {
            throw new Error(`jellyflix-web.zip checksum mismatch: expected ${expected}, got ${actual}`);
        }
        await writeText(zipPath, archive);
        release = { ...JSON.parse(info.toString('utf8')), repo, tag: tag || 'latest' };
    }

    await clean(WEB_DIR);
    unzip(zipPath, WEB_DIR);
    if (!(await exists(join(WEB_DIR, 'index.html')))) {
        throw new Error('The web client archive has no index.html at its root');
    }
    await writeText(join(CACHE, 'web-release.json'), JSON.stringify(release, null, 2) + '\n');
    console.log(`JellyFlix web ${release.version} unpacked into ${WEB_DIR}`);
    return release;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
    const args = parseArgs(process.argv.slice(2));
    fetchWeb({ repo: args.repo, tag: args.tag, zip: args.zip }).catch((err) => {
        console.error(err.message);
        process.exit(1);
    });
}
