import assert from 'node:assert/strict';
import { test } from 'node:test';
import { releaseUrl } from './fetch-web.mjs';
import { parseArgs } from './lib.mjs';
import { fillTemplate, injectIntoHead } from './package-web.mjs';
import { setManifestVersion } from './package-roku.mjs';

test('NativeShell scripts go first in <head>', () => {
    const html = '<!doctype html><html><head><meta charset="utf-8"><script src="main.js"></script></head></html>';
    const result = injectIntoHead(html, ['<script src="a.js"></script>', '<script src="b.js"></script>']);
    assert.ok(result.indexOf('a.js') < result.indexOf('b.js'));
    assert.ok(result.indexOf('b.js') < result.indexOf('main.js'));
    assert.ok(result.startsWith('<!doctype html><html><head>\n'));
});

test('a page without <head> is rejected', () => {
    assert.throws(() => injectIntoHead('<p>hi</p>', ['x']), /no <head>/);
});

test('templates fill known placeholders and keep the rest', () => {
    assert.equal(fillTemplate('v{{version}} {{other}}', { version: '1.2.3' }), 'v1.2.3 {{other}}');
});

test('release URLs point at a tag or the latest release', () => {
    assert.equal(releaseUrl('o/r', undefined, 'a.zip'), 'https://github.com/o/r/releases/latest/download/a.zip');
    assert.equal(releaseUrl('o/r', 'web-1', 'a.zip'), 'https://github.com/o/r/releases/download/web-1/a.zip');
});

test('arguments parse into flags and positionals', () => {
    assert.deepEqual(parseArgs(['webos', '--tag', 'web-1', '--skip-fetch']), { _: ['webos'], tag: 'web-1', 'skip-fetch': true });
});

test('the Roku manifest takes the client version', () => {
    const manifest = 'title=JellyFlix\nmajor_version=0\nminor_version=1\nbuild_version=0\n';
    assert.equal(setManifestVersion(manifest, '1.4.12'), 'title=JellyFlix\nmajor_version=1\nminor_version=4\nbuild_version=12\n');
});

test('themes are complete and the generated code is up to date', async () => {
    const { generate, validate } = await import('./gen-themes.mjs');
    await generate({ check: true });
    const theme = (id, accent) => ({ id, name: id, colors: { background: '#000001', accent } });
    const config = { default: 'a', base: 'a', tokens: { background: '', accent: '' }, themes: [theme('a', '#E50914')] };
    validate(config);
    assert.throws(() => validate({ ...config, themes: [theme('a', '#E50914'), theme('a', '#E50914')] }), /twice/);
    assert.throws(() => validate({ ...config, themes: [theme('a', 'red')] }), /#RRGGBB/);
    assert.throws(() => validate({ ...config, themes: [theme('a', '#000001')] }), /both/);
    assert.throws(() => validate({ ...config, default: 'b' }), /No theme "b"/);
});
