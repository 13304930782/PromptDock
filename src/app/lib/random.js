export function secureRandomInt(maxExclusive, fill = crypto.getRandomValues.bind(crypto)) {
  if (!Number.isSafeInteger(maxExclusive) || maxExclusive < 1 || maxExclusive > 0x100000000) {
    throw new RangeError('maxExclusive must be an integer between 1 and 2^32.');
  }

  const range = 0x100000000;
  const limit = range - (range % maxExclusive);
  const value = new Uint32Array(1);

  do fill(value); while (value[0] >= limit);
  return value[0] % maxExclusive;
}
