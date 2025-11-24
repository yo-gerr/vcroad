const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// Import Express app and tasks
const app = require("./app");
const {scheduledHardDelete} = require("./tasks/scheduledHardDelete");
const {applyUserRole} = require("./callable/user");
const {createAdminUser} = require("./callable/admin");
const {banUser, unbanUser} = require("./callable/ban");
const {trackLoginAttempt} = require("./callable/loginAttempts");
const {autoUnbanExpiredUsers} = require("./tasks/autoUnban");
const {syncAdvisoryStatus} = require("./tasks/syncAdvisoryStatus");

exports.applyUserRole = applyUserRole;
exports.createAdminUser = createAdminUser;
exports.banUser = banUser;
exports.unbanUser = unbanUser;
exports.trackLoginAttempt = trackLoginAttempt;
exports.sheetsProxy = require("./sheetsProxy").sheetsProxy;

const GOOGLE_API_KEY = defineSecret("GOOGLE_API_KEY");

// Expose Express API
const vcroadApiOptions = {secrets: [GOOGLE_API_KEY]};
exports.vcroadApi = onRequest(
    vcroadApiOptions,
    app(GOOGLE_API_KEY),
);

// Scheduled task (daily 12 PM Manila time)
exports.scheduledHardDelete = onSchedule(
    {
      schedule: "0/1 * * * *",
      timeZone: "Asia/Manila",
    },
    async () => {
      await scheduledHardDelete();
    },
);

// Run every 12 PM to check for expired bans
exports.autoUnbanExpiredUsers = onSchedule(
    {
      schedule: "0/1 * * * *",
      timeZone: "Asia/Manila",
    },
    async () => {
      await autoUnbanExpiredUsers();
    },
);

// run syncAdvisoryStatus every 40 minutes to promote scheduled->active and
// expire active->expired
exports.syncAdvisoryStatus = onSchedule(
    {
      schedule: "0/1 * * * *",
      timeZone: "Asia/Manila",
    },
    async () => {
      await syncAdvisoryStatus();
    },
);
