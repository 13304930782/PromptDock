const express = require('express');
const { RELEASE_FILE_NAME, releaseFilePath, releaseInfo } = require('../lib/releaseStorage');

const router = express.Router();

// Intentionally public: approved testers receive this unlisted direct URL.
// The URL is a distribution convenience, not an access-control boundary.
router.get('/promptdock', async (_req, res, next) => {
  try {
    const info = await releaseInfo();
    if (!info.available) return res.status(404).json({ message: 'PromptDock is not available for download yet.' });
    res.set('Cache-Control', 'private, no-store');
    return res.download(releaseFilePath(), RELEASE_FILE_NAME);
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
