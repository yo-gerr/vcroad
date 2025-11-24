const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

/**
 * Track login attempts server-side (by email)
 * Called from client after each login attempt
 */
exports.trackLoginAttempt = onCall(async (request) => {
  const {email, success} = request.data;

  if (!email) {
    throw new Error("Email is required");
  }

  const attemptsRef = admin.firestore()
      .collection("loginAttempts")
      .doc(email.toLowerCase().trim());

  const doc = await attemptsRef.get();
  const now = admin.firestore.Timestamp.now();

  if (!doc.exists) {
    await attemptsRef.set({
      email: email.toLowerCase().trim(),
      failedAttempts: success ? 0 : 1,
      lastAttempt: now,
      lockedUntil: null,
    });
    return {locked: false, attempts: success ? 0 : 1};
  }

  const data = doc.data();
  const lockedUntil = data.lockedUntil ? data.lockedUntil.toDate() : null;

  // Check if still locked
  if (lockedUntil && new Date() < lockedUntil) {
    const remainingMs = lockedUntil.getTime() - Date.now();
    const remainingMinutes = Math.ceil(remainingMs / 60000);
    throw new Error(
        `Account locked. Try again in ${remainingMinutes} minute` +
      `${remainingMinutes === 1 ? "" : "s"}.`,
    );
  }

  if (success) {
    // Clear attempts on success
    await attemptsRef.update({
      failedAttempts: 0,
      lockedUntil: null,
      lastAttempt: now,
    });
    return {locked: false, attempts: 0};
  }

  // Increment failed attempts
  const newAttempts = (data.failedAttempts || 0) + 1;
  const maxAttempts = 5;
  const lockoutMinutes = 5;

  if (newAttempts >= maxAttempts) {
    const lockUntil = new Date(Date.now() + lockoutMinutes * 60 * 1000);
    await attemptsRef.update({
      failedAttempts: 0, // Reset for next cycle
      lockedUntil: admin.firestore.Timestamp.fromDate(lockUntil),
      lastAttempt: now,
    });

    throw new Error(
        `Too many failed attempts. ` +
      `Account locked for ${lockoutMinutes} minutes.`,
    );
  }

  await attemptsRef.update({
    failedAttempts: newAttempts,
    lastAttempt: now,
  });

  return {
    locked: false,
    attempts: newAttempts,
    remaining: maxAttempts - newAttempts,
  };
});
