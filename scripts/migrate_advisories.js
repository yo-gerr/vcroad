#!/usr/bin/env node
/*
 * Backfill the improved `advisories` schema on existing documents:
 *   - advisoryId      = document id (fixes the old '' bug)
 *   - barangayId      = stable barangay key (GeoJSON `id`) resolved from name
 *   - center          = Firestore GeoPoint (from stored map or polylines)
 *   - boundsNE/SW     = Firestore GeoPoints derived from affected roads
 *   - searchKeywords  = denormalized lowercase tokens for array-contains search
 *   - nextStatusAt    = next status-transition time (documented, not evaluated)
 *   - statusUpdatedAt = updatedAt when missing
 *
 * Idempotent: a document already carrying the fields is left untouched, so the
 * script can be re-run safely.
 *
 * Uses the already-authenticated Firebase CLI session (configstore) to mint a
 * short-lived Google access token and updates documents through the Firestore
 * REST API (:commit), bypassing security rules — same as the Admin SDK.
 *
 * Usage:
 *   node scripts/migrate_advisories.js            # dry run (default)
 *   node scripts/migrate_advisories.js --run      # actually write
 *   node scripts/migrate_advisories.js --run -P vcroad-a76a1
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');

const FIREBASE_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';

const args = process.argv.slice(2);
const RUN = args.includes('--run');
const projectIndex = args.indexOf('-P');
const project =
  projectIndex >= 0 && args[projectIndex + 1] ? args[projectIndex + 1] : 'vcroad-a76a1';

const CATEGORY_TITLES = {
  road_closure: 'Road Closure',
  stop_and_go: 'Stop-and-Go',
  one_way: 'One-Way',
  construction: 'Road Work / Construction',
  partial_lane: 'Partial Lane Closure',
  event: 'Event-Related Advisory',
};

function configstorePath() {
  const candidates = [
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return candidates[0];
}

function readConfig() {
  const p = configstorePath();
  if (!fs.existsSync(p)) {
    throw new Error(`Firebase CLI configstore not found at ${p}. Run "firebase login" first.`);
  }
  const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
  const refreshToken = cfg && cfg.tokens && cfg.tokens.refresh_token;
  if (!refreshToken) {
    throw new Error('No refresh_token in firebase configstore. Run "firebase login" first.');
  }
  return { refreshToken };
}

function postJson(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const payload = Buffer.from(body);
    const u = new URL(url);
    const req = https.request(
      {
        method: 'POST',
        hostname: u.hostname,
        path: u.pathname,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': payload.length,
          ...headers,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(data);
          } catch {
            /* ignore */
          }
          resolve({ status: res.statusCode, json, raw: data });
        });
      },
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function mintAccessToken(refreshToken) {
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: FIREBASE_CLIENT_ID,
    client_secret: FIREBASE_CLIENT_SECRET,
    refresh_token: refreshToken,
  }).toString();
  const res = await postJson(OAUTH_TOKEN_URL, body);
  if (res.status !== 200 || !res.json || !res.json.access_token) {
    throw new Error(`Token refresh failed (${res.status}): ${res.raw.slice(0, 400)}`);
  }
  return res.json.access_token;
}

function request(method, url) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request(
      {
        method,
        hostname: u.hostname,
        path: u.pathname + u.search,
        headers: { Authorization: `Bearer ${global.accessToken}` },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(data);
          } catch {
            /* ignore */
          }
          resolve({ status: res.statusCode, json, raw: data });
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

function commit(body) {
  return new Promise((resolve, reject) => {
    const payload = Buffer.from(body);
    const u = new URL(
      `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`,
    );
    const req = https.request(
      {
        method: 'POST',
        hostname: u.hostname,
        path: u.pathname + u.search,
        headers: {
          Authorization: `Bearer ${global.accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': payload.length,
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(data);
          } catch {
            /* ignore */
          }
          resolve({ status: res.statusCode, json, raw: data });
        });
      },
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// ─────────────────────────────────────────────────────────────
// Value helpers (unwrap Firestore field values)
// ─────────────────────────────────────────────────────────────
function unwrap(v) {
  if (v === undefined) return undefined;
  if (v === null) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('nullValue' in v) return null;
  if ('geoPointValue' in v) return v.geoPointValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(unwrap);
  if ('mapValue' in v) {
    const out = {};
    for (const [k, x] of Object.entries(v.mapValue.fields || {})) out[k] = unwrap(x);
    return out;
  }
  return undefined;
}

function fieldOf(doc, key) {
  return doc.fields ? unwrap(doc.fields[key]) : undefined;
}

// Encode helpers for the write payload (partial update, merges with existing)
const F = {
  str: (s) => ({ stringValue: String(s) }),
  arr: (a) => ({ arrayValue: { values: a.map((x) => F.str(x)) } }),
  geo: (lat, lng) => ({
    geoPointValue: { latitude: lat, longitude: lng },
  }),
  ts: (d) => ({ timestampValue: d.toISOString() }),
};

// ─────────────────────────────────────────────────────────────
// Barangay name -> id map from the bundled GeoJSON
// ─────────────────────────────────────────────────────────────
function loadBarangayIdMap() {
  const raw = fs.readFileSync(
    path.join(__dirname, '..', 'assets', 'json', 'barangays.geojson'),
    'utf8',
  );
  const gj = JSON.parse(raw);
  const map = {};
  for (const f of gj.features || []) {
    const props = f.properties || {};
    if (props.barangay && props.id !== undefined) map[props.barangay] = String(props.id);
  }
  return map;
}

// ─────────────────────────────────────────────────────────────
// Field computation
// ─────────────────────────────────────────────────────────────
function polylinePoints(affectedRoads) {
  const pts = [];
  for (const poly of affectedRoads || []) {
    for (const p of poly.points || []) {
      const lat = p.lat ?? p.latitude;
      const lng = p.lng ?? p.longitude;
      if (typeof lat === 'number' && typeof lng === 'number') pts.push({ lat, lng });
    }
  }
  return pts;
}

function centroidOf(points) {
  if (!points.length) return null;
  const sum = points.reduce(
    (acc, p) => ({ lat: acc.lat + p.lat, lng: acc.lng + p.lng }),
    { lat: 0, lng: 0 },
  );
  return { lat: sum.lat / points.length, lng: sum.lng / points.length };
}

function boundsOf(points) {
  if (!points.length) return null;
  let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity;
  for (const p of points) {
    minLat = Math.min(minLat, p.lat);
    maxLat = Math.max(maxLat, p.lat);
    minLng = Math.min(minLng, p.lng);
    maxLng = Math.max(maxLng, p.lng);
  }
  return { ne: { lat: maxLat, lng: maxLng }, sw: { lat: minLat, lng: minLng } };
}

function computeNextStatusAt({ status, scheduleType, startDate, endDate, weekdays, startTime, endTime, now }) {
  if (scheduleType === 'oneTime') {
    if (status === 'scheduled' && startDate && startDate > now) return startDate;
    if (status === 'active' && endDate && endDate > now) return endDate;
    return null;
  }
  // Recurring: scan next 8 days for the earliest window boundary after now.
  const selected = !weekdays || weekdays.length === 0
    ? new Set([1, 2, 3, 4, 5, 6, 7])
    : new Set(weekdays);
  let earliest = null;
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  for (let offset = 0; offset < 8; offset++) {
    const day = new Date(dayStart.getTime() + offset * 86400000);
    if (!selected.has(day.getDay() === 0 ? 7 : day.getDay())) continue; // JS Sun=0 -> 7
    if (!startTime || !endTime) {
      const boundary = new Date(day);
      if (boundary > now && (!earliest || boundary < earliest)) earliest = boundary;
      continue;
    }
    const start = new Date(day);
    start.setHours(startTime.hour, startTime.minute, 0, 0);
    const end = new Date(day);
    end.setHours(endTime.hour, endTime.minute, 0, 0);
    if (end <= start) end.setDate(end.getDate() + 1); // wrap-around window
    if (status === 'scheduled' && start > now && (!earliest || start < earliest)) earliest = start;
    if (status === 'active') {
      const boundary = end > now ? end : start;
      if (boundary > now && (!earliest || boundary < earliest)) earliest = boundary;
    }
  }
  return earliest;
}

function buildSearchKeywords({ barangay, placeName, reason, advisoryType, contractor }) {
  const tokens = [];
  const add = (v) => {
    if (v && typeof v === 'string' && v.trim()) tokens.push(v.trim().toLowerCase());
  };
  add(barangay);
  add(placeName);
  add(reason);
  add(CATEGORY_TITLES[advisoryType]);
  add(contractor);
  return [...new Set(tokens)];
}

// ─────────────────────────────────────────────────────────────
// Migration
// ─────────────────────────────────────────────────────────────
async function listAllAdvisories() {
  const docs = [];
  let pageToken = '';
  let page = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const url = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/advisories?pageSize=1000${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const res = await request('GET', url);
    if (res.status !== 200) {
      throw new Error(`List failed (HTTP ${res.status}): ${(res.raw || '').slice(0, 300)}`);
    }
    docs.push(...(res.json.documents || []));
    pageToken = res.json.nextPageToken || '';
    page += 1;
    if (!pageToken) break;
    if (page > 100) throw new Error('Pagination exceeded 100 pages — aborting.');
  }
  return docs;
}

function buildPatch(doc) {
  const id = decodeURIComponent((doc.name || '').split('/').pop() || '');
  const barangay = fieldOf(doc, 'barangay') || '';
  const advisoryType = fieldOf(doc, 'advisoryType') || '';
  const reason = fieldOf(doc, 'reason') || '';
  const placeName = fieldOf(doc, 'placeName') || null;
  const contractor = fieldOf(doc, 'contractor') || null;
  const scheduleType = fieldOf(doc, 'scheduleType') || 'oneTime';
  const status = fieldOf(doc, 'status') || 'active';
  const startDate = fieldOf(doc, 'startDate');
  const endDate = fieldOf(doc, 'endDate');
  const weekdays = fieldOf(doc, 'weekdays') || null;
  const recStart = fieldOf(doc, 'recurringStartTime') || null;
  const recEnd = fieldOf(doc, 'recurringEndTime') || null;
  const affectedRoads = fieldOf(doc, 'affectedRoads') || null;
  const existingCenter = fieldOf(doc, 'center');

  const now = new Date();
  const points = polylinePoints(affectedRoads);
  const bounds = boundsOf(points);
  const startTime = recStart ? { hour: recStart.hour, minute: recStart.minute } : null;
  const endTime = recEnd ? { hour: recEnd.hour, minute: recEnd.minute } : null;
  const nextStatusAt = computeNextStatusAt({
    status,
    scheduleType,
    startDate,
    endDate,
    weekdays,
    startTime,
    endTime,
    now,
  });

  const patch = {};
  const existingId = fieldOf(doc, 'advisoryId');
  if (!existingId) patch.advisoryId = F.str(id);

  const existingBarangayId = fieldOf(doc, 'barangayId');
  if (!existingBarangayId && barangayIdMap[barangay]) {
    patch.barangayId = F.str(barangayIdMap[barangay]);
  }

  if (existingCenter === undefined || existingCenter === null) {
    const center = centroidOf(points);
    if (center) patch.center = F.geo(center.lat, center.lng);
  }

  if (bounds) {
    const existingNE = fieldOf(doc, 'boundsNE');
    const existingSW = fieldOf(doc, 'boundsSW');
    if (!existingNE) patch.boundsNE = F.geo(bounds.ne.lat, bounds.ne.lng);
    if (!existingSW) patch.boundsSW = F.geo(bounds.sw.lat, bounds.sw.lng);
  }

  const existingKeywords = fieldOf(doc, 'searchKeywords');
  if (!existingKeywords || existingKeywords.length === 0) {
    const keywords = buildSearchKeywords({
      barangay,
      placeName,
      reason,
      advisoryType,
      contractor,
    });
    if (keywords.length > 0) patch.searchKeywords = F.arr(keywords);
  }

  if (nextStatusAt) {
    const existingNext = fieldOf(doc, 'nextStatusAt');
    if (!existingNext) patch.nextStatusAt = F.ts(nextStatusAt);
  }

  const existingStatusUpdatedAt = fieldOf(doc, 'statusUpdatedAt');
  if (!existingStatusUpdatedAt) {
    const updatedAt = fieldOf(doc, 'updatedAt') || now;
    patch.statusUpdatedAt = F.ts(updatedAt instanceof Date ? updatedAt : new Date(updatedAt));
  }

  return { id, patch, hasChanges: Object.keys(patch).length > 0 };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const docs = await listAllAdvisories();
  console.log(`Project: ${project}`);
  console.log(`Found ${docs.length} advisory document(s).\n`);

  const patches = docs.map(buildPatch).filter((p) => p.hasChanges);

  const summary = { advisoryId: 0, barangayId: 0, center: 0, boundsNE: 0, boundsSW: 0, searchKeywords: 0, nextStatusAt: 0, statusUpdatedAt: 0 };
  for (const p of patches) {
    for (const k of Object.keys(summary)) if (k in p.patch) summary[k] += 1;
  }
  console.log('Patches to apply:');
  for (const [k, n] of Object.entries(summary)) console.log(`  ${k.padEnd(18)} ${n}`);

  if (patches.length === 0) {
    console.log('\nNothing to migrate — all documents are already up to date.');
    return;
  }

  if (!RUN) {
    console.log('\nDRY RUN only — nothing was written. Re-run with --run to migrate.');
    return;
  }

  const batches = [];
  for (let i = 0; i < patches.length; i += 400) {
    batches.push(patches.slice(i, i + 400));
  }

  for (let b = 0; b < batches.length; b++) {
    const writes = batches[b].map((p) => ({
      update: {
        name: `projects/${project}/databases/(default)/documents/advisories/${p.id}`,
        fields: p.patch,
      },
    }));
    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      attempt += 1;
      const res = await commit(JSON.stringify({ writes }));
      if (res.status === 200) {
        console.log(`Batch ${b + 1}/${batches.length}: committed ${writes.length} updates.`);
        break;
      }
      if (res.status === 429 || res.status >= 500) {
        const wait = Math.min(1000 * 2 ** attempt, 15000);
        console.log(`Batch ${b + 1}: HTTP ${res.status} — retrying in ${wait / 1000}s`);
        await sleep(wait);
        if (attempt >= 6) throw new Error(`Retry exhausted: ${(res.raw || '').slice(0, 400)}`);
        continue;
      }
      const msg = res.json && res.json.error && res.json.error.message
        ? res.json.error.message
        : (res.raw || '').slice(0, 400);
      throw new Error(`Commit failed (HTTP ${res.status}): ${msg}`);
    }
  }

  console.log('\nDone. Advisory documents migrated.');
}

const barangayIdMap = loadBarangayIdMap();

main().catch((err) => {
  console.error('\nError:', err.message);
  process.exitCode = 1;
});
