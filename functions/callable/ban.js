// functions/callable/user.js
const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.banUser = onCall(async (request) => {
  const {userId, reason, adminId, banType, banDuration} = request.data;

  // Validate required fields
  if (!userId || !reason || !adminId || !banType) {
    throw new Error(
        "Missing required fields: userId, reason, adminId, banType",
    );
  }

  // Validate ban type
  if (!["temporary", "permanent"].includes(banType)) {
    throw new Error(
        "Invalid ban type. Must be 'temporary' or 'permanent'",
    );
  }

  // Validate duration for temporary bans
  if (banType === "temporary") {
    if (!banDuration || banDuration <= 0) {
      throw new Error(
          "Ban duration is required for temporary bans",
      );
    }
  }

  // 1. Disable Firebase Auth account
  await admin.auth().updateUser(userId, {disabled: true});

  // 2. Calculate ban expiration
  let banExpiresAt = null;
  if (banType === "temporary" && banDuration) {
    const now = Date.now();
    // Convert days to milliseconds
    banExpiresAt = new Date(now + banDuration * 24 * 60 * 60 * 1000);
  }

  // 3. Update Firestore user doc
  const now = admin.firestore.FieldValue.serverTimestamp();
  const updateData = {
    isBanned: true,
    banType,
    banReason: reason,
    banBy: adminId,
    bannedAt: now,
    updatedAt: now,
  };

  // Add duration and expiry only for temporary bans
  if (banType === "temporary") {
    updateData.banDuration = banDuration;
    updateData.banExpiresAt =
      admin.firestore.Timestamp.fromDate(banExpiresAt);
  } else {
    // Clear duration fields for permanent bans
    updateData.banDuration = null;
    updateData.banExpiresAt = null;
  }

  await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .update(updateData);

  return {
    success: true,
    message: `User banned successfully (${banType})`,
    banExpiresAt: banExpiresAt ? banExpiresAt.toISOString() : null,
  };
});

exports.unbanUser = onCall(async (request) => {
  const {userId, adminId} = request.data;

  if (!userId || !adminId) {
    throw new Error("Missing required fields: userId, adminId");
  }

  // 1. Re-enable Firebase Auth account
  await admin.auth().updateUser(userId, {disabled: false});

  // 2. Update Firestore user doc
  const now = admin.firestore.FieldValue.serverTimestamp();
  await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .update({
        isBanned: false,
        unbannedBy: adminId,
        unbannedAt: now,
        updatedAt: now,
      // Keep ban history for audit purposes,
      // don't clear banType, banDuration, etc.
      });

  return {success: true, message: "User unbanned successfully"};
});
