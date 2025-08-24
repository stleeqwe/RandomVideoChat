// Firebase Cloud Function: Event-driven matching for /matching_queue
// Deploy with: firebase deploy --only functions:onQueueWrite

const functions = require('firebase-functions');
const admin = require('firebase-admin');

try { admin.initializeApp(); } catch (e) {}

exports.onQueueWrite = functions.database
  .ref('/matching_queue/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const after = change.after.val();

    // Only act when user is waiting
    if (!after || after.status !== 'waiting') {
      return null;
    }

    const myGender = after.gender || 'any';
    const myPref = after.preferredGender || 'any';

    const db = admin.database();
    const queueRef = db.ref('/matching_queue');

    // Fetch all queue entries (optimize with queries and indexes in production)
    const snap = await queueRef.once('value');
    if (!snap.exists()) return null;

    let partnerId = null;
    let partnerData = null;

    snap.forEach(child => {
      const candId = child.key;
      const cand = child.val() || {};
      if (candId === userId) return; // skip self
      if (cand.status !== 'waiting') return; // only waiting

      const candidateGender = cand.gender || 'any';
      const candidatePref = cand.preferredGender || 'any';

      const myPrefOK = (myPref === 'any' || candidateGender === myPref);
      const hisPrefOK = (candidatePref === 'any' || myGender === candidatePref);

      if (myPrefOK && hisPrefOK) {
        partnerId = candId;
        partnerData = cand;
        return true; // break forEach
      }
      return false;
    });

    if (!partnerId) {
      // No partner available; leave user waiting
      return null;
    }

    // Create match
    const matchId = db.ref('/matches').push().key;
    const timestamp = Math.floor(Date.now() / 1000);
    const channelName = `ch_${timestamp}_${Math.floor(Math.random() * 9000 + 1000)}`;

    const updates = {};
    updates[`/matches/${matchId}`] = {
      user1: userId,
      user2: partnerId,
      channelName,
      status: 'active',
      timestamp: admin.database.ServerValue.TIMESTAMP,
    };
    updates[`/matching_queue/${userId}/status`] = 'matched';
    updates[`/matching_queue/${userId}/matchId`] = matchId;
    updates[`/matching_queue/${userId}/channelName`] = channelName;
    updates[`/matching_queue/${partnerId}/status`] = 'matched';
    updates[`/matching_queue/${partnerId}/matchId`] = matchId;
    updates[`/matching_queue/${partnerId}/channelName`] = channelName;

    await db.ref().update(updates);
    console.log(`✅ Matched ${userId} <-> ${partnerId} (matchId=${matchId})`);
    return null;
  });

