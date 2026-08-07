import test from 'node:test';
import assert from 'node:assert/strict';
import { randomPairs, secureRandomInt } from '../src/app/lib/random.js';

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

test('randomPairs independently shuffles each list for the requested passes', () => {
  let reads = 0;
  const pairs = randomPairs(['A', 'B', 'C'], ['1', '2', '3'], 2, 3, () => {
    reads += 1;
    return 0;
  });

  assert.deepEqual(pairs, [['C', '1'], ['A', '2'], ['B', '3']]);
  assert.equal(reads, 10);
  assert.deepEqual(pairs.flatMap(([left]) => left).sort(), ['A', 'B', 'C']);
  assert.deepEqual(pairs.flatMap(([, right]) => right).sort(), ['1', '2', '3']);
  assert.throws(() => randomPairs(['A'], ['1', '2']), RangeError);
  assert.throws(() => randomPairs(['A'], ['1'], 0, 1), RangeError);
});
