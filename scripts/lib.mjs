// Small helpers shared by the build scripts. Node built-ins only, so a fresh checkout needs no `npm install` to build.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { cp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const BUILD = join(ROOT, 'build');
export const CACHE = join(ROOT, '.cache');

export async function readJson(path) {
    return JSON.parse(await readFile(path, 'utf8'));
}

export async function exists(path) {
    try {
        await stat(path);
        return true;
    } catch {
        return false;
    }
}

export async function clean(dir) {
    await rm(dir, { recursive: true, force: true });
    await mkdir(dir, { recursive: true });
}

export async function copy(from, to) {
    await mkdir(dirname(to), { recursive: true });
    await cp(from, to, { recursive: true });
}

export function sha256(buffer) {
    return createHash('sha256').update(buffer).digest('hex');
}

export async function download(url) {
    const response = await fetch(url, { redirect: 'follow' });
    if (!response.ok) {
        throw new Error(`GET ${url} failed: ${response.status} ${response.statusText}`);
    }
    return Buffer.from(await response.arrayBuffer());
}

export function unzip(zipPath, destination) {
    execFileSync('unzip', ['-q', '-o', zipPath, '-d', destination], { stdio: 'inherit' });
}

export function zipDir(sourceDir, zipPath) {
    execFileSync('zip', ['-q', '-r', '-X', zipPath, '.'], { cwd: sourceDir, stdio: 'inherit' });
}

export async function writeText(path, text) {
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, text);
}

/** Parses `--name value` and `--flag` arguments into an object; anything else is a positional argument. */
export function parseArgs(argv) {
    const args = { _: [] };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg.startsWith('--')) {
            const key = arg.slice(2);
            const next = argv[i + 1];
            if (next === undefined || next.startsWith('--')) {
                args[key] = true;
            } else {
                args[key] = next;
                i++;
            }
        } else {
            args._.push(arg);
        }
    }
    return args;
}
