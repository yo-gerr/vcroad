const admin = require("firebase-admin");

const COLLECTION = "advisories";
const BATCH_LIMIT = 500;

/**
 * Promote scheduled -> active and active -> expired in batches.
 * Call this periodically (Cloud Scheduler via onSchedule).
 *
 * This implementation:
 * - Handles startDate/endDate stored as Firestore Timestamps OR strings.
 * - Performs server-side checks for recurring advisories.
 * - Skips documents persisted as 'inactive'.
 * - Writes updatedAt as serverTimestamp() and increments version.
 * - Deactivates recurring active advisories when outside their window.
 */
async function syncAdvisoryStatus() {
  const db = admin.firestore();
  const nowDate = new Date();

  // Manila offset (UTC+8)
  const MANILA_OFFSET_MS = 8 * 60 * 60 * 1000;
  const manilaDate = new Date(nowDate.getTime() + MANILA_OFFSET_MS);

  // Log UTC and Asia/Manila timestamps to verify timezone behavior
  const nowUtc = nowDate.toISOString();
  const nowManilaIso = manilaDate.toISOString();
  console.log("UTC:", nowUtc, "now Asia/Manila (ISO):", nowManilaIso);

  let promoted = 0;
  let expired = 0;
  const deactivated = 0;

  /**
   * Parse possible date field formats into a JS Date.
   * Supports: Firestore Timestamp, ISO string, and exported object.
   *
   * @param {*} value
   * @return {Date|null}
   */
  function parseDateField(value) {
    if (!value) return null;
    if (value instanceof admin.firestore.Timestamp) {
      return value.toDate();
    }
    if (typeof value === "string") {
      const d = new Date(value);
      return isNaN(d.getTime()) ? null : d;
    }
    if (typeof value === "object" && value._seconds != null) {
      return new Date(value._seconds * 1000);
    }
    return null;
  }

  /**
   * Parse recurring time field into {hour, minute}.
   * Accepts "HH:mm" or object with hour/minute.
   *
   * @param {*} value
   * @return {{hour:number,minute:number}|null}
   */
  function parseTimeField(value) {
    if (!value) return null;

    if (typeof value === "string") {
      const parts = value.split(":");
      if (parts.length >= 2) {
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        if (!Number.isNaN(h) && !Number.isNaN(m)) {
          return {hour: h, minute: m};
        }
      }
      return null;
    }

    if (typeof value === "object" && value.hour != null) {
      const minuteVal =
        value.minute != null ? Number(value.minute) : 0;
      return {hour: Number(value.hour), minute: minuteVal};
    }

    return null;
  }

  /**
   * Check whether a recurring advisory is active now.
   * Uses weekdays and recurring start/end time.
   *
   * @param {object} docData
   * @return {boolean}
   */
  function recurringIsActiveNow(docData) {
    const weekdays = Array.isArray(docData.weekdays) ?
      docData.weekdays.map(Number) :
      null;
    if (!weekdays || weekdays.length === 0) return false;

    // use Manila-local weekday/time for comparisons
    const currentWeekday = manilaDate.getDay(); // 0 (Sun) .. 6 (Sat)
    const jsWeekday = ((currentWeekday + 6) % 7) + 1; // 1..7 (Mon..Sun)
    const matches =
      weekdays.includes(jsWeekday) || weekdays.includes(currentWeekday);
    if (!matches) return false;

    const startT = parseTimeField(docData.recurringStartTime);
    const endT = parseTimeField(docData.recurringEndTime);
    if (!startT || !endT) return true; // whole-day recurring

    const nowMinutes =
      manilaDate.getHours() * 60 + manilaDate.getMinutes();
    const startMinutes = Number(startT.hour) * 60 + Number(startT.minute);
    const endMinutes = Number(endT.hour) * 60 + Number(endT.minute);

    if (endMinutes >= startMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }

  /**
   * Generic batched scan for docs matching a base query. updateFn
   * returns an update map or null to skip.
   *
   * @param {function(): firebase.firestore.Query} queryBuilder
   * @param {function} updateFn - (docSnapshot, data) => update map or null
   * @return {Promise<number>} number of updates performed
   */
  async function processScan(queryBuilder, updateFn) {
    let totalUpdated = 0;
    let lastDoc = null;
    let keepGoing = true;

    while (keepGoing) {
      let q = queryBuilder().limit(BATCH_LIMIT);
      if (lastDoc) q = q.startAfter(lastDoc);
      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      let batchOps = 0;

      for (const doc of snap.docs) {
        const data = doc.data();
        // skip explicit inactive docs
        if (data.status === "inactive") continue;

        const maybeUpdate = updateFn(doc, data);
        if (!maybeUpdate) continue;

        batch.update(doc.ref, maybeUpdate);
        batchOps++;
      }

      if (batchOps > 0) {
        await batch.commit();
        totalUpdated += batchOps;
      }

      lastDoc = snap.docs[snap.docs.length - 1];

      // small pause to avoid tight loop / rate limits
      // eslint-disable-next-line no-await-in-loop
      await new Promise((r) => setTimeout(r, 150));

      if (snap.size < BATCH_LIMIT) keepGoing = false;
    }

    return totalUpdated;
  }

  try {
    // ---------- PASS A: scheduled -> maybe active / expired ----------
    promoted += await processScan(
        () =>
          db
              .collection(COLLECTION)
              .where("status", "==", "scheduled"),
        (doc, data) => {
        // skip explicit inactive (processScan already skips, keep guard)
          if (data.status === "inactive") return null;

          const start = parseDateField(data.startDate);
          const end = parseDateField(data.endDate);

          // 1) oneTime scheduled
          if (data.scheduleType === "oneTime") {
          // If end already passed -> expire
            if (end && end.getTime() < nowDate.getTime()) {
              return {
                status: "expired",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: admin.firestore.FieldValue.increment(1),
              };
            }

            // If no start date available, skip (can't decide)
            if (!start) return null;

            // If start <= now -> activate
            if (start.getTime() <= nowDate.getTime()) {
              return {
                status: "active",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: admin.firestore.FieldValue.increment(1),
              };
            }

            // start > now -> remain scheduled (no update)
            return null;
          }

          // 2) recurring scheduled
          if (data.scheduleType === "recurring") {
          // If end already passed -> expire
            if (end && end.getTime() < nowDate.getTime()) {
              return {
                status: "expired",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: admin.firestore.FieldValue.increment(1),
              };
            }

            // If recurring window matches now -> activate
            try {
              if (recurringIsActiveNow(data)) {
                return {
                  status: "active",
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  version: admin.firestore.FieldValue.increment(1),
                };
              }
            } catch (e) {
            // parsing error -> skip to avoid false updates
              return null;
            }

            // Otherwise remain scheduled
            return null;
          }

          return null;
        },
    );

    // ---------- PASS B: active -> maybe expired / scheduled ----------
    expired += await processScan(
        () =>
          db
              .collection(COLLECTION)
              .where("status", "==", "active"),
        (doc, data) => {
          if (data.status === "inactive") return null;

          const end = parseDateField(data.endDate);

          // oneTime active -> expire if end < now
          if (data.scheduleType === "oneTime") {
            if (end && end.getTime() < nowDate.getTime()) {
              return {
                status: "expired",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: admin.firestore.FieldValue.increment(1),
              };
            }
            return null; // otherwise keep active
          }

          // recurring active -> expire if end < now
          if (data.scheduleType === "recurring") {
            if (end && end.getTime() < nowDate.getTime()) {
              return {
                status: "expired",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: admin.firestore.FieldValue.increment(1),
              };
            }

            // if recurring window no longer matches -> set back to scheduled
            try {
              if (!recurringIsActiveNow(data)) {
                return {
                  status: "scheduled",
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  version: admin.firestore.FieldValue.increment(1),
                };
              }
            } catch (e) {
              return null;
            }

            return null; // still active in window
          }

          return null;
        },
    );

    const msgParts = [
      "syncAdvisoryStatus:",
      "promoted=" + promoted + " scheduled->active,",
      "expired=" + expired + " active->expired,",
      "deactivated=" + deactivated + " recurring-active->inactive",
    ];
    console.log(msgParts.join(" "));
  } catch (err) {
    console.error("syncAdvisoryStatus error:", err);
    throw err;
  }
}

module.exports = {
  syncAdvisoryStatus,
};
