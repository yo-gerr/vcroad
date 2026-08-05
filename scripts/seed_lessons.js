#!/usr/bin/env node
/*
 * Seed Philippine road-safety lessons (chapters / lessons / questions)
 * into a Firebase project's Firestore database.
 *
 * Uses the already-authenticated Firebase CLI session (configstore) to mint
 * a short-lived Google access token and writes documents through the
 * Firestore REST API (:commit), which is an admin-level call and bypasses
 * security rules — same as firebase firestore:import / the Admin SDK.
 *
 * Usage:
 *   node scripts/seed_lessons.js            # dry run (default)
 *   node scripts/seed_lessons.js --run      # actually write
 *   node scripts/seed_lessons.js --run -P vcroad-a76a1
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
    const payload = Buffer.isBuffer(body) ? body : Buffer.from(body);
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

function docName(collectionId, docId) {
  // The Firestore REST API expects the raw document path in the JSON `name`
  // field (no percent-encoding). Percent-encoding here would make the server
  // store a literal "%20" as part of the document ID.
  return `projects/${project}/databases/(default)/documents/${collectionId}/${docId}`;
}

function enc(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  if (typeof v === 'number') return { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  if (typeof v === 'object') {
    const keys = Object.keys(v);
    if (keys.length > 0 && keys.every((k) => VALUE_WRAPPERS.includes(k))) {
      // Already a Firestore Value object (e.g. { timestampValue: "..." })
      // — emit it as-is instead of wrapping it in a mapValue.
      return v;
    }
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v).map(([k, x]) => [k, enc(x)]),
        ),
      },
    };
  }
  throw new Error(`Unhandled value type: ${typeof v}`);
}

const VALUE_WRAPPERS = [
  'stringValue',
  'booleanValue',
  'integerValue',
  'doubleValue',
  'timestampValue',
  'nullValue',
  'arrayValue',
  'mapValue',
  'bytesValue',
  'referenceValue',
  'geoPointValue',
];

function timestampFields(obj, key) {
  const out = { ...obj };
  if (typeof out[key] === 'string') {
    out[key] = { timestampValue: out[key] };
  }
  return out;
}

function buildFields(doc) {
  const fields = {};
  for (const [k, v] of Object.entries(doc)) {
    if (v !== undefined) fields[k] = enc(v);
  }
  return fields;
}

function buildWrites(seed) {
  const writes = [];

  for (const c of seed.chapters) {
    const fields = buildFields(
      timestampFields(
        {
          name: c.name,
          order: c.order,
          description: c.description,
          lessonCount: c.lessonCount,
        },
        '__none__',
      ),
    );
    writes.push({ update: { name: docName('chapters', c.id), fields } });
  }

  for (const l of seed.lessons) {
    const data = timestampFields(
      {
        id: l.id,
        title: l.title,
        description: l.description,
        chapterId: l.chapterId,
        lessonNumber: l.lessonNumber,
        isPublished: l.isPublished,
        durationMinutes: l.durationMinutes,
        thumbnailUrl: l.thumbnailUrl || undefined,
        tags: l.tags,
        pointsAvailable: l.pointsAvailable,
        createdAt: seed.seedTimestamp,
        createdBy: seed.createdBy,
        updatedAt: seed.seedTimestamp,
        updatedBy: seed.createdBy,
      },
      'createdAt',
    );
    // updatedAt needs to be a timestamp too
    data.updatedAt = { timestampValue: seed.seedTimestamp };
    writes.push({ update: { name: docName('lessons', l.id), fields: buildFields(data) } });
  }

  for (const q of seed.questions) {
    const data = timestampFields({ ...q }, '__none__');
    delete data.id;
    const fields = {
      id: enc(q.id),
      lessonId: enc(q.lessonId),
      type: enc(q.type),
      questionText: enc(q.questionText),
      points: enc(q.points),
      order: enc(q.order),
      timesAnswered: enc(q.timesAnswered),
      timesCorrect: enc(q.timesCorrect),
    };
    for (const [k, v] of Object.entries(data)) {
      if (k === 'id') continue;
      fields[k] = enc(v);
    }
    writes.push({ update: { name: docName('questions', q.id), fields } });
  }

  return writes;
}

function commit(accessToken, writes) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ writes });
    const u = new URL(
      `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`,
    );
    const req = https.request(
      {
        method: 'POST',
        hostname: u.hostname,
        path: u.pathname + u.search,
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
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
    req.write(body);
    req.end();
  });
}

function listDocs(accessToken, collectionId) {
  return new Promise((resolve, reject) => {
    const u = new URL(
      `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${collectionId}?pageSize=1000`,
    );
    const req = https.request(
      {
        method: 'GET',
        hostname: u.hostname,
        path: u.pathname + u.search,
        headers: { Authorization: `Bearer ${accessToken}` },
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
          resolve({ status: res.statusCode, json });
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const seed = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'seed_data.json'), 'utf8'),
  );

  const nChapters = seed.chapters.length;
  const nLessons = seed.lessons.length;
  const nQuestions = seed.questions.length;
  const nDocs = nChapters + nLessons + nQuestions;

  console.log(`Project: ${project}`);
  console.log(
    `Seed contents: ${nChapters} chapters, ${nLessons} lessons, ${nQuestions} questions (${nDocs} docs)`,
  );

  const writes = buildWrites(seed);
  const batches = [];
  for (let i = 0; i < writes.length; i += 400) {
    batches.push(writes.slice(i, i + 400));
  }
  console.log(`Writes split into ${batches.length} commit batch(es).`);

  if (!RUN) {
    console.log('\nDRY RUN only — nothing was written. Re-run with --run to seed.');
    return;
  }

  const { refreshToken } = readConfig();
  const accessToken = await mintAccessToken(refreshToken);
  console.log('Access token obtained from your firebase CLI session.\n');

  for (let i = 0; i < batches.length; i++) {
    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      attempt += 1;
      const res = await commit(accessToken, batches[i]);
      if (res.status === 200) {
        const writeResults = res.json.writeResults ? res.json.writeResults.length : 0;
        console.log(`Batch ${i + 1}/${batches.length}: committed ${writeResults} writes.`);
        break;
      }
      if (res.status === 429 || res.status >= 500) {
        const wait = Math.min(1000 * 2 ** attempt, 15000);
        console.log(`Batch ${i + 1}: HTTP ${res.status} — retrying in ${wait / 1000}s`);
        await sleep(wait);
        if (attempt >= 6) throw new Error(`Retry exhausted: ${res.raw.slice(0, 400)}`);
        continue;
      }
      const msg = res.json && res.json.error && res.json.error.message
        ? res.json.error.message
        : res.raw.slice(0, 400);
      throw new Error(`Commit failed (HTTP ${res.status}): ${msg}`);
    }
  }

  console.log('\nVerifying by listing collections...');
  for (const col of ['chapters', 'lessons', 'questions']) {
    const res = await listDocs(accessToken, col);
    if (res.status !== 200) {
      console.log(`  ${col}: listing failed (HTTP ${res.status})`);
      continue;
    }
    const count = res.json.documents ? res.json.documents.length : 0;
    console.log(`  ${col}: ${count} document(s)`);
  }

  console.log('\nDone.');
}

main().catch((err) => {
  console.error('\nError:', err.message);
  process.exitCode = 1;
});
