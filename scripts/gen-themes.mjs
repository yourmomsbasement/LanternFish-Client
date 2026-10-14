// Generates the clients' theme code from shared/themes.json:
//   roku/components/common/Themes.brs                   every theme, and the color swap table for the base palette
//   android/app/src/main/res/values/colors.xml          the default theme (connect and error screens)
//
//   node scripts/gen-themes.mjs           write the files
//   node scripts/gen-themes.mjs --check   fail if they're out of date (CI)
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { readJson, ROOT, writeText } from './lib.mjs';

const HEADER = 'Generated from shared/themes.json by scripts/gen-themes.mjs. Edit that file, then run `npm run themes`.';

/** "#e50914" -> "E50914" */
export function rgb(hex) {
    const value = hex.replace('#', '').toUpperCase();
    if (!/^[0-9A-F]{6}$/.test(value)) throw new Error(`"${hex}" isn't a #RRGGBB color`);
    return value;
}

export function validate(config) {
    const tokens = Object.keys(config.tokens);
    const ids = new Set();
    for (const theme of config.themes) {
        if (ids.has(theme.id)) throw new Error(`Theme "${theme.id}" is defined twice`);
        ids.add(theme.id);
        for (const token of tokens) {
            if (!theme.colors[token]) throw new Error(`Theme "${theme.id}" has no "${token}" color`);
            rgb(theme.colors[token]);
        }
        for (const token of Object.keys(theme.colors)) {
            if (!tokens.includes(token)) throw new Error(`Theme "${theme.id}" has unknown color "${token}"`);
        }
    }
    for (const id of [config.default, config.base]) {
        if (!ids.has(id)) throw new Error(`No theme "${id}"`);
    }
    // The base palette's colors identify tokens, so they must all differ (and not be white, which is never themed)
    const base = config.themes.find((t) => t.id === config.base).colors;
    const seen = new Map();
    for (const [token, hex] of Object.entries(base)) {
        const value = rgb(hex);
        if (value === 'FFFFFF') throw new Error(`Base color "${token}" can't be white`);
        if (seen.has(value)) throw new Error(`Base colors "${seen.get(value)}" and "${token}" are both #${value}`);
        seen.set(value, token);
    }
}

export function rokuThemes(config) {
    const base = config.themes.find((t) => t.id === config.base).colors;
    const themes = config.themes.map((theme) => {
        const colors = Object.entries(theme.colors).map(([token, hex]) => `${token}: "0x${rgb(hex)}FF"`).join(', ');
        return `        { id: "${theme.id}", name: "${theme.name}", colors: { ${colors} } }`;
    });
    const swaps = Object.entries(base).map(([token, hex]) => `        "${rgb(hex)}": "${token}"`);
    return `' ${HEADER}

function JF_ThemeList() as Object
    return [
${themes.join(',\n')}
    ]
end function

function JF_DefaultThemeId() as String
    return "${config.default}"
end function

' The colors the XML is written in (the "${config.base}" theme), by RGB, and the token each stands for
function JF_BaseColorTokens() as Object
    return {
${swaps.join(',\n')}
    }
end function
`;
}

export function androidColors(config) {
    const colors = config.themes.find((t) => t.id === config.default).colors;
    return `<?xml version="1.0" encoding="utf-8"?>
<!-- ${HEADER} -->
<resources>
    <color name="background">#FF${rgb(colors.background)}</color>
    <color name="surface">#FF${rgb(colors.surface)}</color>
    <color name="accent">#FF${rgb(colors.accent)}</color>
    <color name="text">#FFFFFFFF</color>
    <color name="text_secondary">#FF${rgb(colors.muted)}</color>
</resources>
`;
}

export async function generate({ check = false } = {}) {
    const config = await readJson(join(ROOT, 'shared', 'themes.json'));
    validate(config);
    const outputs = {
        'roku/components/common/Themes.brs': rokuThemes(config),
        'android/app/src/main/res/values/colors.xml': androidColors(config)
    };
    const stale = [];
    for (const [path, text] of Object.entries(outputs)) {
        const file = join(ROOT, path);
        if (check) {
            const current = await readFile(file, 'utf8').catch(() => '');
            if (current !== text) stale.push(path);
        } else {
            await writeText(file, text);
        }
    }
    if (stale.length) throw new Error(`Out of date (run npm run themes): ${stale.join(', ')}`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
    generate({ check: process.argv.includes('--check') }).catch((err) => {
        console.error(err.message);
        process.exit(1);
    });
}
