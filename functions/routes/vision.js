const express = require("express");
const visionService = require("../services/visionService");
const {validateImage, validateReportMedia} = visionService;

// eslint-disable-next-line new-cap
const router = express.Router();

/**
 * POST /vision/validate
 * Validates an image using Google Vision API (labels + safe search).
 */
router.post("/validate", async (req, res) => {
  const imageBytes = req.body.imageBytes;

  if (!imageBytes) {
    return res.status(400).json({
      error: "Missing imageBytes in request body",
    });
  }

  try {
    const result = await validateImage(imageBytes);
    return res.json(result);
  } catch (err) {
    console.error("Vision API error", err);
    return res.status(500).json({
      error: "Failed to validate image",
    });
  }
});

/**
 * POST /vision/validate-report
 * Validates report media (photo/video) for safe content only.
 */
router.post("/validate-report", async (req, res) => {
  const imageBytes = req.body.imageBytes;

  if (!imageBytes) {
    return res.status(400).json({
      error: "Missing imageBytes in request body",
    });
  }

  try {
    const result = await validateReportMedia(imageBytes);
    return res.json(result);
  } catch (err) {
    console.error("Report media validation error", err);
    return res.status(500).json({
      error: "Failed to validate report media",
    });
  }
});

module.exports = router;
