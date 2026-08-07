import test from 'node:test';
import assert from 'node:assert/strict';
import { secureRandomInt } from '../src/app/lib/random.js';

test('secureRandomInt rejects overflow values instead of introducing modulo bias', () => {
  const samples = [0xffffffff, 7];
  let reads = 0;
  const result = secureRandomInt(6, (buffer) => {
    buffer[0] = samples[reads++];
    return buffer;
  });

  assert.equal(result, 1);
  assert.equal(reads, 2);
});

test('secureRandomInt validates its range', () => {
  assert.throws(() => secureRandomInt(0), RangeError);
  assert.throws(() => secureRandomInt(1.5), RangeError);
});
