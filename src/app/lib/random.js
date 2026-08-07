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

export function randomPairs(left, right, randomInt = secureRandomInt) {
  if (!left.length || left.length !== right.length) {
    throw new RangeError('Both lists must contain the same non-zero number of items.');
  }

  const shuffle = (items) => {
    const result = [...items];
    for (let index = result.length - 1; index > 0; index -= 1) {
      const swapIndex = randomInt(index + 1);
      [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
    }
    return result;
  };

  const shuffledLeft = shuffle(left);
  const shuffledRight = shuffle(right);
  return shuffledLeft.map((item, index) => [item, shuffledRight[index]]);
}
