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

export function randomSwap(items, randomInt = secureRandomInt) {
  const result = [...items];
  if (result.length < 2) return result;

  const firstIndex = randomInt(result.length);
  let secondIndex = randomInt(result.length - 1);
  if (secondIndex >= firstIndex) secondIndex += 1;
  [result[firstIndex], result[secondIndex]] = [result[secondIndex], result[firstIndex]];
  return result;
}

export function randomOrder(items, randomInt = secureRandomInt) {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
  }
  return result;
}
