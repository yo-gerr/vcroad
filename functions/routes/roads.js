const express = require("express");
const fetch = require("node-fetch");

// eslint-disable-next-line new-cap
const router = express.Router();

module.exports = (GOOGLE_API_KEY) => {
  router.post("/snap", async (req, res) => {
    try {
      const {points} = req.body;

      if (!points || !Array.isArray(points) || points.length === 0) {
        console.warn("⚠️ No points provided in body.");
        return res.status(400).json({error: "No points provided"});
      }

      // ✅ get the actual API key value from Firebase Secret Manager
      const apiKey = GOOGLE_API_KEY.value();
      if (!apiKey) {
        console.error("❌ GOOGLE_API_KEY is not set or accessible");
        return res.status(500).json({error: "Google API key not set"});
      }

      const path = points.map((p) => `${p.lat},${p.lng}`).join("|");
      const url =
        "https://roads.googleapis.com/v1/snapToRoads?" +
        `path=${encodeURIComponent(path)}` +
        `&interpolate=true&key=${apiKey}`;

      console.log(
          "📤 Sending to Roads API:",
          url.replace(apiKey, "***MASKED***"),
      );
      const response = await fetch(url);
      const data = await response.json();

      if (!response.ok) {
        console.error("❌ Roads API error:", data);
        return res.status(500).json({
          error: "Roads API request failed",
          details: data,
        });
      }

      if (data.error || !data.snappedPoints) {
        console.warn("⚠️ No snapped points returned:", data);
        return res.json({snappedPoints: []});
      }

      const snappedPoints = data.snappedPoints.map((pt) => ({
        lat: pt.location.latitude,
        lng: pt.location.longitude,
      }));

      console.log("✅ Snapped points count:", snappedPoints.length);
      res.json({snappedPoints});
    } catch (err) {
      console.error("🔥 Server error in /roads/snap:", err);
      res.status(500).json({
        error: "Internal Server Error",
        details: err.message,
      });
    }
  });

  return router;
};
