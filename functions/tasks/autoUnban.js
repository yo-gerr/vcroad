const admin = require("firebase-admin");

exports.autoUnbanExpiredUsers = async () => {
  const now = admin.firestore.Timestamp.now();

  const snapshot = await admin
      .firestore()
      .collection("users")
      .where("isBanned", "==", true)
      .where("banType", "==", "temporary")
      .where("banExpiresAt", "<=", now)
      .get();

  const batch = admin.firestore().batch();
  const promises = [];

  snapshot.forEach((doc) => {
    const userId = doc.id;

    // Re-enable auth
    promises.push(
        admin.auth().updateUser(userId, {disabled: false}),
    );

    // Update Firestore
    batch.update(doc.ref, {
      isBanned: false,
      unbannedBy: "system",
      unbannedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await Promise.all(promises);
  await batch.commit();

  console.log(`Auto-unbanned ${snapshot.size} users`);
  return {unbannedCount: snapshot.size};
};
