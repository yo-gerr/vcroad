const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");

// Import routes
const placesRoutes = require("./routes/places");
const visionRoutes = require("./routes/vision");
const roadsRoutes = require("./routes/roads");
const staticMapRoutes = require("./routes/staticmap");

module.exports = (GOOGLE_API_KEY) => {
  const app = express();
  app.use(cors({origin: true}));
  app.use(bodyParser.json({limit: "6mb"}));

  // Mount routes
  app.use("/places", placesRoutes(GOOGLE_API_KEY));
  app.use("/vision", visionRoutes);
  app.use("/roads", roadsRoutes(GOOGLE_API_KEY));
  app.use("/staticmap", staticMapRoutes(GOOGLE_API_KEY));

  return app;
};
