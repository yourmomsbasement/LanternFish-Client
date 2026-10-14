// Runs the Roku helper tests (roku/tests/*.test.brs) in the @rokucommunity/brs interpreter. No device needed.
import { execFileSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT } from './lib.mjs';

const roku = join(ROOT, 'roku');
// The component scripts the tests call into
const sources = [
    'components/common/Utils.brs',
    'components/common/DeviceProfile.brs',
    'components/screens/ConnectScreen.brs',
    'components/common/Theme.brs',
    'components/common/Themes.brs'
].map((file) => join(roku, file));

let failed = false;
for (const test of readdirSync(join(roku, 'tests')).filter((f) => f.endsWith('.test.brs'))) {
    const output = execFileSync(join(ROOT, 'node_modules', '.bin', 'brs'), [join(roku, 'tests', test), ...sources], { encoding: 'utf8' });
    process.stdout.write(output);
    const passes = (output.match(/^PASS /gm) || []).length;
    if (/^FAIL /m.test(output) || passes === 0) failed = true;
}
if (failed) {
    console.error('Roku tests failed');
    process.exit(1);
}
