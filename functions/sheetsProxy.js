const fetch = require("node-fetch");
const {onRequest} = require("firebase-functions/v2/https");

const APPS_SCRIPT_URL = process.env.APPS_SCRIPT_URL ||
    "https://script.google.com/macros/s/AKfycbw8UCpYCeGBa0qAByJWw9AhSC58A_9sCRFeP-lH857z4vCnJmDw81cPBfOYT5R6K3gl/exec";
const APPS_SCRIPT_API_KEY = process.env.APPS_SCRIPT_API_KEY || "";

exports.sheetsProxy = onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const payload = (req.body && Object.keys(req.body).length) ? req.body : {};
    if (APPS_SCRIPT_API_KEY) payload.apiKey = APPS_SCRIPT_API_KEY;

    const proxied = await fetch(APPS_SCRIPT_URL, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });

    const text = await proxied.text();
    res.status(proxied.status).send(text);
  } catch (err) {
    console.error("sheetsProxy error", err);
    res.status(500).json({error: String(err)});
  }
});
