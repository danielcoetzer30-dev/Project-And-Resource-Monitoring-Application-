// Adds the two forecasting fields to projects already in Firestore.
//
// Usage:
//   node tool/patch_forecast_fields.js          list only, changes nothing
//   node tool/patch_forecast_fields.js --apply  write the fields
//
// Why this exists rather than re-running seed_firestore.js: that script POSTs
// with a document ID, which creates. On a document that already exists it gets
// a 409 and skips, so a re-run would change nothing.
//
// This PATCHes with an updateMask naming exactly two fields. Firestore will
// not touch anything outside that mask, so a mistake here cannot damage the
// scores, factors, seams or anything else on those documents.
//
// Writes are refused by the production rules. Run this only while the
// temporary seed rules are deployed, then put the real ones back:
//
//   firebase deploy --only firestore:rules

const PROJECT_ID = 'project-health-monitor-436da';
const API_KEY = 'AIzaSyDDuSEz62NL8Q3i975aKXiVkt319TwbZ1U';
const ORG_ID = 'demo-org';

const ROOT = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const COLLECTION = `organisations/${ORG_ID}/projects`;

/// Must match the seeded projects in tool/seed_firestore.js and the mock
/// repository, so the three stay in step.
const FIELDS = {
  p1: { scheduleTotalDays: 90, velocityRatio: 0.62 },
  p2: { scheduleTotalDays: 80, velocityRatio: 0.78 },
  p3: { scheduleTotalDays: 120, velocityRatio: 0.95 },
  p4: { scheduleTotalDays: 100, velocityRatio: 1.05 },
};

const apply = process.argv.includes('--apply');

function readField(fields, name) {
  const v = fields?.[name];
  if (!v) return undefined;
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.stringValue !== undefined) return v.stringValue;
  return undefined;
}

async function list() {
  const response = await fetch(`${ROOT}/${COLLECTION}?key=${API_KEY}`);
  if (!response.ok) {
    throw new Error(
      `Could not read ${COLLECTION}: ${response.status} ${await response.text()}`,
    );
  }
  const body = await response.json();
  return body.documents ?? [];
}

async function patch(id, values) {
  const mask = Object.keys(values)
    .map((f) => `updateMask.fieldPaths=${f}`)
    .join('&');

  const url = `${ROOT}/${COLLECTION}/${id}?${mask}&key=${API_KEY}`;

  const response = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        scheduleTotalDays: { integerValue: String(values.scheduleTotalDays) },
        velocityRatio: { doubleValue: values.velocityRatio },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`${id} failed: ${response.status} ${await response.text()}`);
  }
}

async function main() {
  console.log(`${apply ? 'Patching' : 'Inspecting'} ${COLLECTION}\n`);

  const documents = await list();
  if (documents.length === 0) {
    console.log('No project documents found. Nothing to patch.');
    console.log('Run tool/seed_firestore.js first if the database is empty.');
    return;
  }

  console.log(`Found ${documents.length} projects:\n`);

  for (const doc of documents) {
    const id = doc.name.split('/').pop();
    const f = doc.fields ?? {};
    const name = readField(f, 'name') ?? '(no name)';
    const total = readField(f, 'scheduleTotalDays');
    const ratio = readField(f, 'velocityRatio');

    const has = total !== undefined && ratio !== undefined;
    console.log(
      `  ${id}  ${name}` +
        (has
          ? `  — already has scheduleTotalDays=${total}, velocityRatio=${ratio}`
          : '  — missing the forecast fields'),
    );

    if (!apply) continue;

    const values = FIELDS[id];
    if (!values) {
      console.log(`     skipped: no known values for ${id}`);
      continue;
    }

    await patch(id, values);
    console.log(
      `     set scheduleTotalDays=${values.scheduleTotalDays}, ` +
        `velocityRatio=${values.velocityRatio}`,
    );
  }

  if (!apply) {
    console.log('\nNothing was changed. Re-run with --apply to write.');
    return;
  }

  // Read back rather than trusting the write.
  console.log('\nVerifying:');
  for (const doc of await list()) {
    const id = doc.name.split('/').pop();
    const f = doc.fields ?? {};
    console.log(
      `  ${id}: scheduleTotalDays=${readField(f, 'scheduleTotalDays')}, ` +
        `velocityRatio=${readField(f, 'velocityRatio')}, ` +
        `score=${readField(f, 'score')} (untouched)`,
    );
  }

  console.log('\nDone. Put the production rules back now:');
  console.log('  firebase deploy --only firestore:rules');
}

main().catch((error) => {
  console.error('\nFailed:', error.message);
  process.exit(1);
});
