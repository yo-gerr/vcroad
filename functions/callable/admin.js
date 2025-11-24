// functions/callable/admin.js
const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

/**
 * Sanitize incoming data for Firestore.
 *
 * @param {Object<string, any>} obj
 * @return {Object<string, any>}
 */
function sanitizeData(obj) {
  if (!obj || typeof obj !== "object") return obj;

  return Object.fromEntries(
      Object.entries(obj).map(([key, value]) => {
        if (value === undefined) return [key, null];
        if (value instanceof Date) return [key, value.toISOString()];
        return [key, value];
      }),
  );
}

exports.createAdminUser = onCall(async (request) => {
  if (!request.auth) throw new Error("Unauthenticated request");

  const callerUid = request.auth.uid;
  const caller = await admin.auth().getUser(callerUid);

  // ✅ Only sysadmin can create admins
  if (!caller.customClaims || caller.customClaims.role !== "sysadmin") {
    throw new Error("Unauthorized: Only sysadmin can create admins");
  }

  const {email, password, userDetails} = request.data || {};
  if (!email || !password) {
    throw new Error("Missing email or password");
  }

  // 1. Create Firebase Auth user
  const newUser = await admin.auth().createUser({email, password});

  // 2. Set custom claims
  await admin.auth().setCustomUserClaims(newUser.uid, {role: "admin"});

  // 3. Sanitize but ignore client’s role/verification/createdAt
  const safeDetails = sanitizeData(userDetails || {});

  // 4. Enforce authoritative schema
  const now = admin.firestore.FieldValue.serverTimestamp();
  const profile = {
    ...safeDetails,
    email, // <-- Add this line

    // 🔒 Enforced fields
    userId: newUser.uid,
    role: "admin",
    isVerified: true,
    verifiedBy: callerUid,
    verifiedAt: now,
    isBanned: false,

    // 🔒 Audit
    createdBy: callerUid,
    createdAt: now,
    updatedBy: callerUid,
    updatedAt: now,

    // 🔒 Nullables (explicit to avoid schema drift)
    deletedAt: null,
    scheduledForDeletionAt: null,
    bannedAt: null,
    banBy: null,
    banReason: null,
    unbanRequestAt: null,
    unbannedAt: null,
    unbannedBy: null,

    // 🔒 Default counters
    confirmReactionsCount: 0,
    verifiedReportsCount: 0,
    lessonsFinishedCount: 0,
  };

  // 5. Save Firestore profile
  await admin.firestore().collection("users").doc(newUser.uid).set(profile);

  return {uid: newUser.uid, email: newUser.email, role: "admin"};
});
