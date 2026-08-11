const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');

const RELEASE_FILE_NAME = 'PromptDock.dmg';
const DEFAULT_RELEASE_DIRECTORY = path.resolve(__dirname, '..', '..', 'uploads', 'releases');

function isDmg(buffer) {
  return Buffer.isBuffer(buffer)
    && buffer.length >= 512
    && buffer.subarray(buffer.length - 512, buffer.length - 508).equals(Buffer.from('koly'));
}

function releaseFilePath(directory = DEFAULT_RELEASE_DIRECTORY) {
  return path.join(directory, RELEASE_FILE_NAME);
}

async function saveRelease(buffer, directory = DEFAULT_RELEASE_DIRECTORY) {
  if (!isDmg(buffer)) throw new Error('The uploaded file is not a valid DMG image.');
  await fs.mkdir(directory, { recursive: true });
  const temporaryPath = path.join(directory, `.${RELEASE_FILE_NAME}.${crypto.randomUUID()}.tmp`);
  try {
    await fs.writeFile(temporaryPath, buffer, { flag: 'wx', mode: 0o600 });
    await fs.rename(temporaryPath, releaseFilePath(directory));
  } catch (error) {
    await fs.unlink(temporaryPath).catch(() => undefined);
    throw error;
  }
  return releaseInfo(directory);
}

async function releaseInfo(directory = DEFAULT_RELEASE_DIRECTORY) {
  try {
    const stat = await fs.stat(releaseFilePath(directory));
    return {
      available: stat.isFile(),
      file_name: RELEASE_FILE_NAME,
      size: stat.size,
      updated_at: stat.mtime.toISOString(),
    };
  } catch (error) {
    if (error.code === 'ENOENT') {
      return { available: false, file_name: RELEASE_FILE_NAME, size: 0, updated_at: null };
    }
    throw error;
  }
}

module.exports = {
  RELEASE_FILE_NAME,
  isDmg,
  releaseFilePath,
  releaseInfo,
  saveRelease,
};
