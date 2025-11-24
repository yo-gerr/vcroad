const vision = require("@google-cloud/vision");

// Reuse Vision API client
const visionClient = new vision.ImageAnnotatorClient();

// Only keep keyword-driven categories for selfie/id.
// Traffic will NOT be validated by label matching — see validateImage below.
const CATEGORY_KEYWORDS = {
  selfie: ["face", "person", "portrait", "selfie"],
  id: ["document", "license", "id card", "passport", "text", "paper"],
};
const SAFE_SEARCH_FLAGS = ["LIKELY", "VERY_LIKELY"];

/**
 * Extracts lowercase labels from Vision API annotations.
 * @param {Array} labelAnnotations
 * @return {Array<string>}
 */
function extractLabels(labelAnnotations) {
  return Array.isArray(labelAnnotations) ?
    labelAnnotations.map((l) => l.description.toLowerCase()) :
    [];
}

/**
 * Determines the image category based on keywords.
 * @param {Array<string>} labels
 * @return {string}
 */
function classifyCategory(labels) {
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (labels.some((label) => keywords.includes(label))) {
      return category;
    }
  }
  return "unknown";
}

/**
 * Checks SafeSearch flags for adult, violence, and racy content.
 * @param {Object} safeSearch
 * @return {boolean}
 */
function isSafeContent(safeSearch) {
  return !SAFE_SEARCH_FLAGS.includes(safeSearch.adult) &&
    !SAFE_SEARCH_FLAGS.includes(safeSearch.violence) &&
    !SAFE_SEARCH_FLAGS.includes(safeSearch.racy);
}

/**
 * Returns a human-readable validation reason.
 * @param {boolean} valid
 * @param {string} category
 * @return {string}
 */
function getValidationReason(valid, category) {
  if (valid) return "Valid image";
  return category === "unknown" ?
    "Image not recognized as selfie/ID (treated as traffic only if safe)" :
    "Image failed safe content check";
}

/**
 * Validates an image using Vision API.
 * @param {string} imageBytes - Base64 encoded image
 * @return {Promise<Object>}
 */
async function validateImage(imageBytes) {
  const [result] = await visionClient.annotateImage({
    image: {content: imageBytes},
    features: [
      {type: "LABEL_DETECTION", maxResults: 10},
      {type: "SAFE_SEARCH_DETECTION"},
    ],
  });

  const labels = extractLabels(result.labelAnnotations);
  const safeSearch = result.safeSearchAnnotation || {};
  // Determine selfie/id via labels; traffic is NOT determined by labels.
  const categoryFromLabels = classifyCategory(labels);
  const isSafe = isSafeContent(safeSearch);

  // Resolve final category & validity:
  // - If labels indicate selfie/id => use that category and
  //   require safe content.
  // - If labels do NOT indicate selfie/id (unknown) => treat as
  //   "traffic" candidate.
  //   traffic validity is based only on safe content (not on labels).
  let category;
  let isValid;
  if (categoryFromLabels === "selfie" || categoryFromLabels === "id") {
    category = categoryFromLabels;
    isValid = isSafe;
  } else {
    // Not matched as selfie/id -> consider it traffic candidate.
    category = "traffic";
    // Traffic is validated purely by safe-search (no label requirement).
    isValid = isSafe;
  }

  return {
    valid: isValid,
    category,
    reason: getValidationReason(isValid, category),
    labels,
    safeSearch,
  };
}

/**
 * Validates report media (photo/video thumbnail) for safe content only.
 * Does NOT check categories - only ensures content is safe.
 * @param {string} imageBytes - Base64 encoded image
 * @return {Promise<Object>}
 */
async function validateReportMedia(imageBytes) {
  const [result] = await visionClient.annotateImage({
    image: {content: imageBytes},
    features: [
      {type: "SAFE_SEARCH_DETECTION"},
    ],
  });

  const safeSearch = result.safeSearchAnnotation || {};
  const isSafe = isSafeContent(safeSearch);

  return {
    valid: isSafe,
    reason: isSafe ?
      "Media content is safe" :
      "Media contains inappropriate content " +
      "(adult, violent, or explicit material)",
    safeSearch,
  };
}

module.exports = {validateImage, validateReportMedia};
