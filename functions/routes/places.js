const express = require("express");
const fetch = require("node-fetch");

module.exports = (GOOGLE_API_KEY) => {
  // eslint-disable-next-line new-cap
  const router = express.Router();

  /**
   * GET /places/autocomplete
   * Returns Google Places Autocomplete predictions for a given input.
   */
  router.get("/autocomplete", async (req, res) => {
    const input = req.query.input;
    const sessionToken = req.query.sessiontoken;

    if (!input) return res.status(400).json({error: "Missing input query"});

    const params = new URLSearchParams({
      input,
      key: GOOGLE_API_KEY.value(),
      language: "en",
    });
    if (sessionToken) params.append("sessiontoken", sessionToken);

    try {
      const response = await fetch(
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?" + params,
      );
      const data = await response.json();
      return res.json(data);
    } catch (err) {
      console.error("Google Places API error", err);
      return res.status(500).json({error: "Failed to fetch Google Places API"});
    }
  });

  /**
   * GET /places/details
   * Returns Google Place details by place_id.
   */
  router.get("/details", async (req, res) => {
    const placeId = req.query.place_id;
    const sessionToken = req.query.sessiontoken;

    if (!placeId) {
      return res.status(400).json({error: "place_id is required"});
    }

    const params = new URLSearchParams({
      place_id: placeId,
      key: GOOGLE_API_KEY.value(),
      fields: "geometry/location,geometry/viewport,name,formatted_address",
    });
    if (sessionToken) {
      params.append("sessiontoken", sessionToken);
    }

    try {
      const response = await fetch(
          `https://maps.googleapis.com/maps/api/place/details/json?${params}`,
      );
      const data = await response.json();
      return res.json(data);
    } catch (err) {
      console.error("Place details error:", err);
      return res.status(500).json({error: "Failed to fetch place details"});
    }
  });

  /**
   * GET /places/geocode
   * Returns address details for a latlng coordinate.
   */
  router.get("/geocode", async (req, res) => {
    const latlng = req.query.latlng;

    if (!latlng) return res.status(400).json({error: "Missing latlng"});

    const params = new URLSearchParams({
      latlng,
      key: GOOGLE_API_KEY.value(),
    });

    try {
      const response = await fetch(
          "https://maps.googleapis.com/maps/api/geocode/json?" + params,
      );
      const data = await response.json();
      return res.json(data);
    } catch (err) {
      console.error("Geocode API error", err);
      return res.status(500).json({error: "Failed to fetch geocode data"});
    }
  });

  return router;
};
