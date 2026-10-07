// Seeds Firestore with a demonstration organisation.
//
// Usage:
//   node tool/seed_firestore.js
//
// Uses the Firestore REST API rather than the Admin SDK, so it needs no
// service-account key — just the public web API key already in
// lib/firebase_options.dart.
//
// Writes are refused by the production security rules (projects, squads and
// signals are read-only to clients by design). Run this only while the
// temporary seed rules are deployed, then put the real rules back:
//
//   firebase deploy --only firestore:rules
//
// Everything written here is demonstration data. The clients and projects are
// invented; the shape matches docs/SCHEMA.md exactly.

const PROJECT_ID = 'project-health-monitor-436da';
const API_KEY = 'AIzaSyDDuSEz62NL8Q3i975aKXiVkt319TwbZ1U';
const ORG_ID = 'demo-org';

const ROOT = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// --- REST value encoding ----------------------------------------------------
// Firestore's REST API wants every value tagged with its type.

function encode(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encode) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFields(value) } };
  }
  throw new Error(`Cannot encode ${typeof value}`);
}

function encodeFields(object) {
  const fields = {};
  for (const [key, value] of Object.entries(object)) {
    fields[key] = encode(value);
  }
  return fields;
}

async function write(collectionPath, documentId, data) {
  const url =
    `${ROOT}/${collectionPath}?documentId=${encodeURIComponent(documentId)}&key=${API_KEY}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: encodeFields(data) }),
  });

  if (!response.ok) {
    const body = await response.text();
    // 409 means the document already exists, which is fine on a re-run.
    if (response.status === 409) {
      console.log(`  = ${collectionPath}/${documentId} (already exists)`);
      return;
    }
    throw new Error(
      `${collectionPath}/${documentId} failed: ${response.status} ${body}`,
    );
  }

  console.log(`  + ${collectionPath}/${documentId}`);
}

// --- Seam helpers -----------------------------------------------------------

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function shortDate(date) {
  return `${date.getDate()} ${MONTHS[date.getMonth()]}`;
}

/// Builds a 30-day seam from runs of states, with flags on given indices.
function buildSeam(runs, flagIndices) {
  const states = [];
  for (const [state, count] of runs) {
    for (let i = 0; i < count; i++) states.push(state);
  }

  const today = new Date();
  const flags = new Set(flagIndices);

  return states.map((state, i) => {
    const day = new Date(today);
    day.setDate(today.getDate() - (states.length - 1 - i));
    return {
      state,
      periodLabel: shortDate(day),
      flagged: flags.has(i),
    };
  });
}

function hoursAgo(hours) {
  return new Date(Date.now() - hours * 3600 * 1000);
}

function hoursFromNow(hours) {
  return new Date(Date.now() + hours * 3600 * 1000);
}

// --- Data -------------------------------------------------------------------

const squads = [
  {
    id: 's1',
    name: 'Platform squad',
    headcount: 4,
    capacityUsed: 1.28,
    activeProjectCount: 2,
    velocityTrend: -0.31,
  },
  {
    id: 's2',
    name: 'Mobile squad',
    headcount: 3,
    capacityUsed: 1.02,
    activeProjectCount: 1,
    velocityTrend: -0.12,
  },
  {
    id: 's3',
    name: 'Integrations squad',
    headcount: 3,
    capacityUsed: 0.78,
    activeProjectCount: 1,
    velocityTrend: 0.04,
  },
];

const projects = [
  {
    id: 'p1',
    name: 'Ledger rebuild',
    client: 'Thornhill Financial',
    squadId: 's1',
    score: 28,
    openSignals: 4,
    budgetBurn: 0.94,
    scheduleDaysRemaining: 11,
    scheduleTotalDays: 90,
    velocityRatio: 0.62,
    loadSheddingHoursLost: 6.5,
    seam: buildSeam(
      [['onTrack', 9], ['watch', 6], ['atRisk', 8], ['critical', 7]],
      [15, 22, 26, 29],
    ),
    factors: [
      { name: 'Budget burn', value: 18, weight: 0.25, detail: '94% of budget spent with 11 days of scope remaining' },
      { name: 'Task velocity', value: 31, weight: 0.25, detail: 'Throughput down 38% against this squad’s own baseline' },
      { name: 'Issue complexity ratio', value: 24, weight: 0.2, detail: 'Open issues skewing heavier as simpler work is cleared' },
      { name: 'Commit volume', value: 42, weight: 0.15, detail: 'Steady, but concentrated in one area of the codebase' },
      { name: 'Idle-time ratio', value: 35, weight: 0.15, detail: '6.5 hours lost to outages, already excluded from this score' },
    ],
  },
  {
    id: 'p2',
    name: 'Fleet tracker v2',
    client: 'Marula Logistics',
    squadId: 's2',
    score: 47,
    openSignals: 2,
    budgetBurn: 0.61,
    scheduleDaysRemaining: 34,
    scheduleTotalDays: 80,
    velocityRatio: 0.78,
    loadSheddingHoursLost: 3.0,
    seam: buildSeam(
      [['onTrack', 12], ['watch', 9], ['atRisk', 6], ['watch', 3]],
      [19, 24],
    ),
    factors: [
      { name: 'Budget burn', value: 62, weight: 0.25, detail: '61% spent against 58% of the schedule elapsed' },
      { name: 'Task velocity', value: 44, weight: 0.25, detail: 'Slowed for three sprints running' },
      { name: 'Issue complexity ratio', value: 51, weight: 0.2, detail: 'Backlog weight stable' },
      { name: 'Commit volume', value: 38, weight: 0.15, detail: 'Down 22%, tracking the outage window' },
      { name: 'Idle-time ratio', value: 40, weight: 0.15, detail: '3 hours lost to outages this week' },
    ],
  },
  {
    id: 'p3',
    name: 'Clinic booking portal',
    client: 'Sibanye Health',
    squadId: 's1',
    score: 64,
    openSignals: 1,
    budgetBurn: 0.42,
    scheduleDaysRemaining: 52,
    scheduleTotalDays: 120,
    velocityRatio: 0.95,
    loadSheddingHoursLost: 2.0,
    seam: buildSeam([['watch', 7], ['onTrack', 14], ['watch', 9]], [8]),
    factors: [
      { name: 'Budget burn', value: 71, weight: 0.25, detail: 'Tracking slightly under plan' },
      { name: 'Task velocity', value: 58, weight: 0.25, detail: 'Recovered after last sprint’s dip' },
      { name: 'Issue complexity ratio', value: 66, weight: 0.2, detail: 'Healthy mix of work sizes' },
      { name: 'Commit volume', value: 69, weight: 0.15, detail: 'Consistent across the squad' },
      { name: 'Idle-time ratio', value: 55, weight: 0.15, detail: '2 hours lost to outages this week' },
    ],
  },
  {
    id: 'p4',
    name: 'POS integration',
    client: 'Kloof Retail Group',
    squadId: 's3',
    score: 82,
    openSignals: 0,
    budgetBurn: 0.35,
    scheduleDaysRemaining: 68,
    scheduleTotalDays: 100,
    velocityRatio: 1.05,
    loadSheddingHoursLost: 1.5,
    seam: buildSeam([['onTrack', 18], ['watch', 4], ['onTrack', 8]], []),
    factors: [
      { name: 'Budget burn', value: 88, weight: 0.25, detail: '35% spent against 32% of the schedule elapsed' },
      { name: 'Task velocity', value: 79, weight: 0.25, detail: 'Steady against baseline' },
      { name: 'Issue complexity ratio', value: 84, weight: 0.2, detail: 'Backlog clearing evenly' },
      { name: 'Commit volume', value: 77, weight: 0.15, detail: 'Well distributed across the squad' },
      { name: 'Idle-time ratio', value: 81, weight: 0.15, detail: 'Backup power holding through outages' },
    ],
  },
];

const signals = [
  {
    id: 'sig1',
    title: 'Ledger rebuild will exhaust its budget before scope closes',
    because: 'Burn reached 94% with 11 days of work left. At the current rate the budget runs out around 8 days early.',
    severity: 'critical',
    projectId: 'p1',
    raisedAt: hoursAgo(2),
    infrastructureRelated: false,
  },
  {
    id: 'sig2',
    title: 'Platform squad has been over capacity for nine days',
    because: 'Committed work sits at 128% of available capacity across two projects. Sustained over-allocation precedes schedule slip.',
    severity: 'atRisk',
    projectId: 'p1',
    raisedAt: hoursAgo(6),
    infrastructureRelated: false,
  },
  {
    id: 'sig3',
    title: 'Stage 2 outage will remove 2.5 hours from tomorrow',
    because: 'Scheduled outage overlaps the Mobile squad’s working window. Capacity forecasts have been adjusted; no project has been scored down for it.',
    severity: 'watch',
    projectId: 'p2',
    raisedAt: hoursAgo(1),
    infrastructureRelated: true,
  },
  {
    id: 'sig4',
    title: 'Fleet tracker velocity down three sprints running',
    because: 'Throughput fell 12%, 18% and 9% against the squad baseline. The decline is steeper than outage hours alone explain.',
    severity: 'atRisk',
    projectId: 'p2',
    raisedAt: hoursAgo(24),
    infrastructureRelated: false,
  },
  {
    id: 'sig5',
    title: 'Clinic portal backlog weight rising',
    because: 'Remaining issues are trending more complex as simpler work is cleared. Watch the next two sprints.',
    severity: 'watch',
    projectId: 'p3',
    raisedAt: hoursAgo(48),
    infrastructureRelated: false,
  },
];

const outages = [
  {
    id: 'out1',
    stage: 2,
    start: hoursFromNow(3),
    end: hoursFromNow(5.5),
    affectedSquadIds: ['s1', 's2'],
  },
  {
    id: 'out2',
    stage: 2,
    start: hoursFromNow(27),
    end: hoursFromNow(29.5),
    affectedSquadIds: ['s1', 's2', 's3'],
  },
];

const sources = [
  {
    id: 'src1',
    type: 'github',
    label: 'Ledger rebuild repo',
    remoteId: 'northbridge/ledger',
    isEnabled: true,
    lastSyncedAt: hoursAgo(1),
  },
  {
    id: 'src2',
    type: 'clickUp',
    label: 'Delivery board',
    remoteId: '901234567',
    isEnabled: true,
    lastSyncedAt: hoursAgo(2),
  },
];

// --- Run --------------------------------------------------------------------

async function main() {
  console.log(`Seeding ${PROJECT_ID} / organisations/${ORG_ID}\n`);

  console.log('organisation');
  await write('organisations', ORG_ID, {
    name: 'Northbridge Software (demo)',
    createdAt: new Date('2026-01-15T08:00:00Z'),
    memberCount: 10,
  });

  console.log('squads');
  for (const { id, ...data } of squads) {
    await write(`organisations/${ORG_ID}/squads`, id, {
      ...data,
      updatedAt: new Date(),
    });
  }

  console.log('projects');
  for (const { id, ...data } of projects) {
    await write(`organisations/${ORG_ID}/projects`, id, {
      ...data,
      updatedAt: new Date(),
    });
  }

  console.log('signals');
  for (const { id, ...data } of signals) {
    await write(`organisations/${ORG_ID}/signals`, id, data);
  }

  console.log('outages');
  for (const { id, ...data } of outages) {
    await write(`organisations/${ORG_ID}/outages`, id, data);
  }

  console.log('sources');
  for (const { id, ...data } of sources) {
    await write(`organisations/${ORG_ID}/sources`, id, data);
  }

  console.log('settings');
  await write(`organisations/${ORG_ID}/settings`, 'scoringWeights', {
    budgetBurn: 0.25,
    taskVelocity: 0.25,
    issueComplexity: 0.2,
    commitVolume: 0.15,
    idleTime: 0.15,
  });

  console.log('\nDone. Put the production rules back now:');
  console.log('  firebase deploy --only firestore:rules');
}

main().catch((error) => {
  console.error('\nSeeding failed:', error.message);
  process.exit(1);
});
