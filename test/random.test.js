import test from 'node:test';
import assert from 'node:assert/strict';
import { randomOrder, randomSwap, secureRandomInt } from '../src/app/lib/random.js';

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

test('randomSwap swaps exactly two positions without mutating the input', () => {
  const input = ['A', 'B', 'C'];
  let reads = 0;
  const result = randomSwap(input, () => {
    reads += 1;
    return 0;
  });

  assert.deepEqual(result, ['B', 'A', 'C']);
  assert.deepEqual(input, ['A', 'B', 'C']);
  assert.equal(reads, 2);
});

test('randomOrder creates a random order without mutating the input', () => {
  const input = ['A', 'B', 'C'];
  const result = randomOrder(input, () => 0);

  assert.deepEqual(result, ['B', 'C', 'A']);
  assert.deepEqual(input, ['A', 'B', 'C']);
});
