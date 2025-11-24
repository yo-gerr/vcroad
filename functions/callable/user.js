const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.applyUserRole = onCall(async (request) => {
  if (!request.auth) throw new Error("Unauthenticated request");

  const uid = request.auth.uid;
  const userDocRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userDocRef.get();
  if (!userDoc.exists) throw new Error("User not found in Firestore");

  const role = userDoc.data().role || "user";

  await admin.auth().setCustomUserClaims(uid, {role});

  return {role: String(role)};
});
