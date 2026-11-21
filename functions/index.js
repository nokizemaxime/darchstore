const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');

setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });
initializeApp();

const db = getFirestore();
const STAT_TYPES = new Set(['view', 'download', 'install', 'update']);
const APP_ID = /^[A-Za-z0-9_-]{1,128}$/;
const DEVICE_ID = /^[A-Za-z0-9]{8,128}$/;
const TOPIC = 'darchstore-updates';

function assertAdmin(request) {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Droit d’administration requis.');
  }
}

function dayKey(value) {
  const date = value && typeof value.toDate === 'function' ? value.toDate() : new Date();
  return date.toISOString().slice(0, 10);
}

exports.aggregateStats = onDocumentCreated('stats_events/{eventId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  if (!STAT_TYPES.has(data.type)) return;
  if (typeof data.appId !== 'string' || !APP_ID.test(data.appId)) return;

  const packageName = typeof data.packageName === 'string' ? data.packageName.slice(0, 200) : '';
  const day = dayKey(data.createdAt);
  const markerRef = db.collection('stats_markers').doc(event.params.eventId);
  const rollupRef = db.collection('stats_rollups').doc(data.appId);
  const dailyRef = db.collection('stats_daily').doc(day);

  await db.runTransaction(async (tx) => {
    const marker = await tx.get(markerRef);
    if (marker.exists) return;
    tx.set(markerRef, { createdAt: FieldValue.serverTimestamp() });
    tx.set(rollupRef, {
      appId: data.appId,
      packageName,
      [data.type]: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(dailyRef, {
      [data.type]: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
});

exports.cleanupApp = onDocumentDeleted({
  document: 'apps/{appId}',
  timeoutSeconds: 120,
}, async (event) => {
  const appId = event.params.appId;
  if (!APP_ID.test(appId)) return;

  const versions = await db.collection(`apps/${appId}/versions`).get();
  let batch = db.batch();
  let count = 0;
  for (const version of versions.docs) {
    batch.delete(version.ref);
    count += 1;
    if (count === 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();

  const bucket = getStorage().bucket();
  await bucket.deleteFiles({ prefix: `releases/${appId}/`, force: true }).catch((error) => {
    console.error('Nettoyage APK ignoré', error);
  });
  await bucket.deleteFiles({ prefix: `icons/${appId}/`, force: true }).catch((error) => {
    console.error('Nettoyage icône ignoré', error);
  });
});

exports.notifyCatalogUpdate = onCall(async (request) => {
  assertAdmin(request);
  const raw = request.data ? request.data.appId : undefined;
  let appId = '';
  if (raw !== undefined && raw !== null && raw !== '') {
    if (typeof raw !== 'string' || !APP_ID.test(raw)) {
      throw new HttpsError('invalid-argument', 'Identifiant d’application invalide.');
    }
    appId = raw;
  }

  await getMessaging().send({
    topic: TOPIC,
    data: {
      type: 'catalog_refresh',
      appId,
    },
    android: { priority: 'high' },
  });
  return { ok: true };
});

exports.purgeDevice = onCall({ timeoutSeconds: 120 }, async (request) => {
  assertAdmin(request);
  const deviceId = request.data ? request.data.deviceId : '';
  if (typeof deviceId !== 'string' || !DEVICE_ID.test(deviceId)) {
    throw new HttpsError('invalid-argument', 'Identifiant d’appareil invalide.');
  }

  let deletedEvents = 0;
  for (let round = 0; round < 20; round += 1) {
    const snap = await db.collection('stats_events').where('deviceId', '==', deviceId).limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deletedEvents += snap.size;
    if (snap.size < 400) break;
  }
  await db.collection('devices').doc(deviceId).delete();
  return { deletedEvents };
});
