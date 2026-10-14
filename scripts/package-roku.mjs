// Zips the Roku channel for sideloading (http://<roku-ip> → Development Application Installer) or for the Roku
// Developer Dashboard. The manifest's version is set from package.json.
//
//   node scripts/package-roku.mjs   → dist/lanternfish-roku-<version>.zip
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { BUILD, clean, copy, readJson, ROOT, writeText, zipDir } from './lib.mjs';

// Development files that don't belong on the device
const EXCLUDE = new Set(['tests', 'bsconfig.json']);

/** Sets major_version, minor_version and build_version in a Roku manifest from "1.2.3". */
export function setManifestVersion(manifest, version) {
    const [major = '0', minor = '0', build = '0'] = version.split(/[.-]/).map((part) => part.replace(/\D/g, '') || '0');
    return manifest
        .replace(/^major_version=.*$/m, `major_version=${major}`)
        .replace(/^minor_version=.*$/m, `minor_version=${minor}`)
        .replace(/^build_version=.*$/m, `build_version=${build}`);
}

export async function packageRoku() {
    const { version } = await readJson(join(ROOT, 'package.json'));
    const source = join(ROOT, 'roku');
    const out = join(BUILD, 'roku');
    await clean(out);
    for (const entry of await readdir(source)) {
        if (!EXCLUDE.has(entry)) await copy(join(source, entry), join(out, entry));
    }
    const manifest = await readFile(join(out, 'manifest'), 'utf8');
    await writeText(join(out, 'manifest'), setManifestVersion(manifest, version));

    const dist = join(ROOT, 'dist');
    await writeText(join(dist, '.keep'), '');
    const zipPath = join(dist, `lanternfish-roku-${version}.zip`);
    zipDir(out, zipPath);
    console.log(`Lanternfish for Roku ${version} packaged as ${zipPath}`);
    return zipPath;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
    packageRoku().catch((err) => {
        console.error(err.message);
        process.exit(1);
    });
}
