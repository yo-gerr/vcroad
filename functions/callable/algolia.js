const {onCall} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const algoliasearch = require("algoliasearch");

const ALGOLIA_APP_ID = defineSecret("ALGOLIA_APP_ID");
const ALGOLIA_ADMIN_KEY = defineSecret("ALGOLIA_ADMIN_KEY");

exports.getSecuredSearchKey = onCall(
    {secrets: [ALGOLIA_APP_ID, ALGOLIA_ADMIN_KEY]},
    async (request) => {
    // Require authentication
      if (!request.auth) {
        throw new Error("User must be logged in");
      }

      const {role, barangayName} = request.data;

      // Get Algolia credentials
      const appId = ALGOLIA_APP_ID.value();
      const adminKey = ALGOLIA_ADMIN_KEY.value();

      // Initialize client inside the function
      const client = algoliasearch(appId, adminKey);

      // Build filters based on role
      let filters = "role:sysadmin = false"; // Always exclude sysadmin accounts

      if (role === "admin" && barangayName) {
      // Admin can only see users in their barangay
        filters += ` AND barangay.name:"${barangayName.replace(/"/g, "\\\"")}"`;
      }

      // Key expires in 30 minutes
      const validUntil = Math.floor(Date.now() / 1000) + 60 * 30;

      const securedApiKey = client.generateSecuredApiKey(adminKey, {
        filters,
        validUntil,
        restrictIndices: ["users"],
        userToken: request.auth.uid,
      });

      return {
        appId: appId,
        apiKey: securedApiKey,
        validUntil,
      };
    },
);
