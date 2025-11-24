const admin = require("firebase-admin");

const firestore = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

exports.scheduledHardDelete = async () => {
  const now = new Date();

  // Query for users whose scheduled deletion time is in the past
  const snapshot = await firestore
      .collection("users")
      .where("scheduledForDeletionAt", "<=", now)
      .get();

  for (const doc of snapshot.docs) {
    const uid = doc.id;
    const data = doc.data();

    try {
      // Delete files from storage
      if (data.validIdPath) {
        await storage.bucket().file(data.validIdPath).delete().catch(() => { });
      }
      if (data.selfiePath) {
        await storage.bucket().file(data.selfiePath).delete().catch(() => { });
      }

      // Delete Firestore record
      await firestore.collection("users").doc(uid).delete();

      // Delete Authentication account
      await auth.deleteUser(uid);
    } catch (err) {
      console.error(`Failed to delete ${uid}:`, err);
    }
  }
};
