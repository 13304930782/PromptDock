const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs/promises');
const os = require('os');
const path = require('path');
const { isDmg, releaseFilePath, releaseInfo, saveRelease } = require('../src/lib/releaseStorage');

function dmgFixture(size = 1024) {
  const buffer = Buffer.alloc(size);
  buffer.write('koly', size - 512);
  return buffer;
}

test('recognizes the UDIF trailer used by DMG images', () => {
  assert.equal(isDmg(dmgFixture()), true);
  assert.equal(isDmg(Buffer.from('not a dmg')), false);
});

test('replaces the current release and reports its metadata', async (t) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'cuegrove-release-'));
  t.after(() => fs.rm(directory, { recursive: true, force: true }));
  const buffer = dmgFixture(2048);

  const saved = await saveRelease(buffer, directory);
  const stored = await fs.readFile(releaseFilePath(directory));
  const info = await releaseInfo(directory);

  assert.deepEqual(stored, buffer);
  assert.equal(saved.available, true);
  assert.equal(info.size, buffer.length);
});
