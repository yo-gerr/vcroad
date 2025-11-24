const express = require("express");
const fetch = require("node-fetch");
// encode polylines compactly
let polyline;
try {
  // preferred maintained package
  polyline = require("@mapbox/polyline");
} catch (err) {
  // fallback to legacy package name if present
  polyline = require("polyline");
}

// eslint-disable-next-line new-cap
const router = express.Router();

module.exports = (GOOGLE_API_KEY) => {
  /**
     * POST /staticmap
     * Accepts either:
     *  - polylines: [{ color, weight, encoded }]  (legacy)
     *  - paths: [{ color, weight, dashed, points: [{lat, lng}, ...] }]
     *  - markers: [{ color, lat, lng }]
     *
     * Returns: PNG image buffer
     */
  router.post("/", async (req, res) => {
    try {
      const {
        center,
        zoom,
        width = 500,
        height = 450,
        // support both names
        polylines = [],
        paths = [],
        markers = [],
        maptype = "roadmap",
      } = req.body;

      const params = [];
      if (center) {
        params.push(`center=${center.lat},${center.lng}`);
      }
      if (zoom) {
        params.push(`zoom=${zoom}`);
      }
      params.push(`size=${width}x${height}`);
      params.push(`format=png`);
      params.push(`maptype=${maptype}`);
      params.push(`key=${GOOGLE_API_KEY.value()}`);

      // STATIC MAP STYLING
      // Default: remove POI labels for a cleaner exported map.
      // The client may pass `styles` (array of style strings) to override/add.
      // Example style string: "feature:poi|element:labels|visibility:off"
      const bodyStyles = req.body.styles;
      if (Array.isArray(bodyStyles) && bodyStyles.length > 0) {
        for (const s of bodyStyles) {
          if (typeof s === "string" && s.trim()) {
            params.push(`style=${encodeURIComponent(s)}`);
          }
        }
      } else {
        // fallback default: hide POI labels
        const defaultStyleStr =
          "feature:poi|element:labels|visibility:off";
        params.push(`style=${encodeURIComponent(defaultStyleStr)}`);
      }

      // Markers (legacy behavior)
      for (const marker of markers) {
        const markerStr = [
          marker.color ? `color:${marker.color}` : "",
          `${marker.lat},${marker.lng}`,
        ]
            .filter(Boolean)
            .join("|");
        params.push(`markers=${encodeURIComponent(markerStr)}`);
      }

      // Helper to push a path param from an encoded polyline or raw points
      const pushEncodedPath = (encoded, color, weight) => {
        const polyStr = [
          color ? `color:${color}` : "",
          weight ? `weight:${weight}` : "",
          encoded ? `enc:${encoded}` : "",
        ]
            .filter(Boolean)
            .join("|");
        params.push(`path=${encodeURIComponent(polyStr)}`);
      };

      // 1) Support legacy polylines array (already encoded)
      if (Array.isArray(polylines) && polylines.length > 0) {
        for (const poly of polylines) {
          if (poly.encoded) {
            pushEncodedPath(poly.encoded, poly.color, poly.weight);
          } else if (poly.points) {
            // encode points if provided
            const pts = poly.points.map((p) => [p.lat, p.lng]);
            const enc = polyline.encode(pts);
            pushEncodedPath(enc, poly.color, poly.weight);
          }
        }
      }

      // 2) Support new 'paths' array with explicit points
      if (Array.isArray(paths) && paths.length > 0) {
        for (const p of paths) {
          if (p.points && Array.isArray(p.points) && p.points.length > 0) {
            // points as [{lat,lng}, ...]
            const pts = p.points.map((pt) => [pt.lat, pt.lng]);
            // encode for compact URL
            const enc = polyline.encode(pts);
            pushEncodedPath(enc, p.color, p.weight);
          }
        }
      }

      const url =
        "https://maps.googleapis.com/maps/api/staticmap?" +
        params.join("&");

      const response = await fetch(url);
      if (!response.ok) {
        return res
            .status(response.status)
            .json({error: "Failed to fetch static map"});
      }
      const buffer = await response.buffer();
      res.set("Content-Type", "image/png");
      return res.send(buffer);
    } catch (err) {
      console.error("Static Map API error", err);
      return res.status(500).json({error: "Static Map API error"});
    }
  });

  return router;
};
