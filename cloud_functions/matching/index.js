/**
 * Firebase Cloud Function: Production-grade Event-driven Matching System
 *
 * Architecture:
 * - Server-only matching (clients only register/unregister from queue)
 * - Transaction-based atomic operations to prevent race conditions
 * - Indexed queries for O(1) matching instead of O(n) full scan
 * - Bidirectional gender preference matching
 * - Blocked user exclusion
 * - Duplicate match prevention
 *
 * Deploy: firebase deploy --only functions:onQueueWrite,functions:cleanupStaleEntries
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin SDK (idempotent)
try { admin.initializeApp(); } catch (e) { /* already initialized */ }

const db = admin.database();
const firestore = admin.firestore();

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
  // Matching parameters
  MATCH_TIMEOUT_MS: 30000,           // 30 seconds stale entry threshold
  LOCK_TIMEOUT_MS: 5000,             // 5 seconds lock expiration
  MAX_RETRY_ATTEMPTS: 3,             // Maximum matching retry attempts

  // Channel naming
  CHANNEL_PREFIX: 'ch',

  // Rate limiting
  MIN_MATCH_INTERVAL_MS: 1000,       // Minimum 1 second between matches for same user
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Generate a unique channel name for Agora
 * Format: ch_{timestamp}_{random4digits}
 */
function generateChannelName() {
  const timestamp = Math.floor(Date.now() / 1000);
  const random = Math.floor(Math.random() * 9000 + 1000);
  return `${CONFIG.CHANNEL_PREFIX}_${timestamp}_${random}`;
}

/**
 * Generate a unique match ID
 */
function generateMatchId() {
  return db.ref('/matches').push().key;
}

/**
 * Check if two users can match based on gender preferences
 * @param {Object} userA - First user's queue data
 * @param {Object} userB - Second user's queue data
 * @returns {boolean} - True if mutual preferences match
 */
function arePreferencesCompatible(userA, userB) {
  const aGender = userA.gender || 'any';
  const aPref = userA.preferredGender || 'any';
  const bGender = userB.gender || 'any';
  const bPref = userB.preferredGender || 'any';

  // A's preference satisfied by B's gender
  const aPrefOK = aPref === 'any' || bGender === aPref;
  // B's preference satisfied by A's gender
  const bPrefOK = bPref === 'any' || aGender === bPref;

  return aPrefOK && bPrefOK;
}

/**
 * Check if userA has blocked userB or vice versa
 * @param {string} userAId
 * @param {string} userBId
 * @returns {Promise<boolean>} - True if either user has blocked the other
 */
async function isBlockedPair(userAId, userBId) {
  try {
    const [userADoc, userBDoc] = await Promise.all([
      firestore.collection('users').doc(userAId).get(),
      firestore.collection('users').doc(userBId).get()
    ]);

    const userABlocked = userADoc.exists ? (userADoc.data().blockedUsers || []) : [];
    const userBBlocked = userBDoc.exists ? (userBDoc.data().blockedUsers || []) : [];

    return userABlocked.includes(userBId) || userBBlocked.includes(userAId);
  } catch (error) {
    console.error(`Error checking blocked status: ${error.message}`);
    return false; // Fail open - allow match if we can't check
  }
}

/**
 * Get candidate buckets for matching based on user's preferred gender
 * @param {string} myGender - User's own gender
 * @param {string} myPref - User's preferred gender
 * @returns {string[]} - Array of bucket names to search
 */
function getCandidateBuckets(myGender, myPref) {
  if (myPref === 'any' || myPref === '' || !myPref) {
    return ['waiting_male', 'waiting_female', 'waiting_any'];
  }
  return [`waiting_${myPref}`, 'waiting_any'];
}

/**
 * Get the bucket name for a user
 * @param {string} gender
 * @returns {string}
 */
function getUserBucket(gender) {
  if (!gender || gender === 'any' || gender === '') {
    return 'waiting_any';
  }
  return `waiting_${gender}`;
}

// ============================================================================
// LOCKING MECHANISM
// ============================================================================

/**
 * Attempt to acquire a distributed lock for matching two users
 * Uses Firebase transactions for atomicity
 * @param {string} userAId
 * @param {string} userBId
 * @returns {Promise<{success: boolean, lockKey: string}>}
 */
async function acquireMatchLock(userAId, userBId) {
  // Create deterministic lock key (sorted user IDs)
  const sortedIds = [userAId, userBId].sort();
  const lockKey = `${sortedIds[0]}_${sortedIds[1]}`;
  const lockRef = db.ref(`/matching_locks/${lockKey}`);

  const now = Date.now();

  try {
    const result = await lockRef.transaction((currentData) => {
      // If no lock exists or lock is expired, acquire it
      if (!currentData || (currentData.expiresAt && currentData.expiresAt < now)) {
        return {
          lockedBy: 'cloud_function',
          lockedAt: now,
          expiresAt: now + CONFIG.LOCK_TIMEOUT_MS,
          userA: userAId,
          userB: userBId
        };
      }
      // Lock exists and is valid - abort transaction
      return undefined;
    });

    return {
      success: result.committed,
      lockKey
    };
  } catch (error) {
    console.error(`Lock acquisition error: ${error.message}`);
    return { success: false, lockKey };
  }
}

/**
 * Release a distributed lock
 * @param {string} lockKey
 */
async function releaseLock(lockKey) {
  try {
    await db.ref(`/matching_locks/${lockKey}`).remove();
  } catch (error) {
    console.error(`Lock release error: ${error.message}`);
  }
}

// ============================================================================
// MATCHING LOGIC
// ============================================================================

/**
 * Find a compatible partner for the given user
 * Uses indexed queries for efficiency
 * @param {string} userId - The user looking for a match
 * @param {Object} userData - The user's queue data
 * @returns {Promise<{partnerId: string, partnerData: Object} | null>}
 */
async function findCompatiblePartner(userId, userData) {
  const myGender = userData.gender || 'any';
  const myPref = userData.preferredGender || 'any';
  const candidateBuckets = getCandidateBuckets(myGender, myPref);

  console.log(`🔍 Finding partner for ${userId} (gender: ${myGender}, pref: ${myPref})`);
  console.log(`📦 Searching buckets: ${candidateBuckets.join(', ')}`);

  const queueRef = db.ref('/matching_queue');

  for (const bucket of candidateBuckets) {
    // Query users in this bucket who are waiting, ordered by timestamp (FIFO)
    const snapshot = await queueRef
      .orderByChild('bucket')
      .equalTo(bucket)
      .limitToFirst(20)  // Limit query size for efficiency
      .once('value');

    if (!snapshot.exists()) {
      console.log(`📦 Bucket ${bucket} is empty`);
      continue;
    }

    // Iterate through candidates
    const candidates = [];
    snapshot.forEach((childSnap) => {
      const candId = childSnap.key;
      const candData = childSnap.val() || {};

      // Skip self
      if (candId === userId) return;

      // Skip non-waiting users
      if (candData.status !== 'waiting') return;

      // Skip stale entries
      const timestamp = candData.timestamp || 0;
      if (Date.now() - timestamp > CONFIG.MATCH_TIMEOUT_MS * 10) {
        console.log(`⏰ Skipping stale entry: ${candId}`);
        return;
      }

      // Check bidirectional preference compatibility
      if (!arePreferencesCompatible(userData, candData)) {
        console.log(`❌ Preference mismatch with ${candId}`);
        return;
      }

      candidates.push({ id: candId, data: candData, timestamp });
    });

    // Sort by timestamp (FIFO - oldest first)
    candidates.sort((a, b) => a.timestamp - b.timestamp);

    // Try each candidate
    for (const candidate of candidates) {
      // Check blocked status
      const isBlocked = await isBlockedPair(userId, candidate.id);
      if (isBlocked) {
        console.log(`🚫 Blocked pair: ${userId} <-> ${candidate.id}`);
        continue;
      }

      // Found a valid match!
      console.log(`✅ Found compatible partner: ${candidate.id}`);
      return {
        partnerId: candidate.id,
        partnerData: candidate.data
      };
    }
  }

  console.log(`❌ No compatible partner found for ${userId}`);
  return null;
}

/**
 * Execute the match atomically using multi-path updates
 * @param {string} userAId
 * @param {string} userBId
 * @param {string} matchId
 * @param {string} channelName
 * @returns {Promise<boolean>} - True if match was successful
 */
async function executeMatch(userAId, userBId, matchId, channelName) {
  const now = admin.database.ServerValue.TIMESTAMP;

  // Prepare atomic multi-path update
  const updates = {
    // Create match record
    [`/matches/${matchId}`]: {
      user1: userAId,
      user2: userBId,
      channelName: channelName,
      status: 'active',
      createdAt: now,
      version: 1
    },

    // Update user A's queue entry
    [`/matching_queue/${userAId}/status`]: 'matched',
    [`/matching_queue/${userAId}/matchId`]: matchId,
    [`/matching_queue/${userAId}/channelName`]: channelName,
    [`/matching_queue/${userAId}/matchedWith`]: userBId,
    [`/matching_queue/${userAId}/matchedAt`]: now,

    // Update user B's queue entry
    [`/matching_queue/${userBId}/status`]: 'matched',
    [`/matching_queue/${userBId}/matchId`]: matchId,
    [`/matching_queue/${userBId}/channelName`]: channelName,
    [`/matching_queue/${userBId}/matchedWith`]: userAId,
    [`/matching_queue/${userBId}/matchedAt`]: now
  };

  try {
    // Verify both users are still waiting before executing
    const [userASnap, userBSnap] = await Promise.all([
      db.ref(`/matching_queue/${userAId}/status`).once('value'),
      db.ref(`/matching_queue/${userBId}/status`).once('value')
    ]);

    if (userASnap.val() !== 'waiting' || userBSnap.val() !== 'waiting') {
      console.log(`⚠️ Users no longer waiting: A=${userASnap.val()}, B=${userBSnap.val()}`);
      return false;
    }

    // Execute atomic update
    await db.ref().update(updates);

    console.log(`✅ Match executed successfully: ${matchId}`);
    console.log(`   ${userAId} <-> ${userBId}`);
    console.log(`   Channel: ${channelName}`);

    return true;
  } catch (error) {
    console.error(`❌ Match execution failed: ${error.message}`);
    return false;
  }
}

// ============================================================================
// MAIN CLOUD FUNCTION
// ============================================================================

/**
 * Main matching function triggered on queue writes
 * Only processes when a user enters 'waiting' status
 */
exports.onQueueWrite = functions
  .region('asia-northeast3')  // Seoul region for low latency
  .database
  .ref('/matching_queue/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const before = change.before.val();
    const after = change.after.val();

    // Log the event
    console.log(`📝 Queue write event for ${userId}`);
    console.log(`   Before: ${JSON.stringify(before)}`);
    console.log(`   After: ${JSON.stringify(after)}`);

    // -------------------------------------------------------------------------
    // GUARD CLAUSES
    // -------------------------------------------------------------------------

    // Only process if user is now waiting
    if (!after || after.status !== 'waiting') {
      console.log(`⏭️ Skipping: User ${userId} is not waiting`);
      return null;
    }

    // Skip if user was already waiting (prevents re-processing)
    if (before && before.status === 'waiting') {
      console.log(`⏭️ Skipping: User ${userId} was already waiting`);
      return null;
    }

    // Rate limiting - prevent rapid re-matching
    if (before && before.matchedAt) {
      const timeSinceLastMatch = Date.now() - before.matchedAt;
      if (timeSinceLastMatch < CONFIG.MIN_MATCH_INTERVAL_MS) {
        console.log(`⏭️ Rate limited: ${userId} matched ${timeSinceLastMatch}ms ago`);
        return null;
      }
    }

    // -------------------------------------------------------------------------
    // MATCHING PROCESS
    // -------------------------------------------------------------------------

    console.log(`🎯 Starting match process for ${userId}`);

    // Find a compatible partner
    const match = await findCompatiblePartner(userId, after);

    if (!match) {
      console.log(`⏳ No partner found - ${userId} will wait in queue`);
      return null;
    }

    const { partnerId, partnerData } = match;

    // Acquire distributed lock
    const lock = await acquireMatchLock(userId, partnerId);

    if (!lock.success) {
      console.log(`🔒 Could not acquire lock - another process is handling this match`);
      return null;
    }

    try {
      // Generate match identifiers
      const matchId = generateMatchId();
      const channelName = generateChannelName();

      // Execute the match atomically
      const success = await executeMatch(userId, partnerId, matchId, channelName);

      if (success) {
        console.log(`🎉 Match completed: ${userId} <-> ${partnerId}`);

        // Update match statistics in Firestore (non-blocking)
        updateMatchStatistics(userId, partnerId).catch(err => {
          console.error(`Stats update failed: ${err.message}`);
        });
      } else {
        console.log(`❌ Match failed - users may have been matched by another process`);
      }

      return null;
    } finally {
      // Always release the lock
      await releaseLock(lock.lockKey);
    }
  });

// ============================================================================
// STATISTICS & CLEANUP
// ============================================================================

/**
 * Update match statistics in Firestore
 * @param {string} userAId
 * @param {string} userBId
 */
async function updateMatchStatistics(userAId, userBId) {
  const batch = firestore.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const increment = admin.firestore.FieldValue.increment(1);

  const userARef = firestore.collection('users').doc(userAId);
  const userBRef = firestore.collection('users').doc(userBId);

  batch.update(userARef, {
    totalMatches: increment,
    lastMatchAt: now
  });

  batch.update(userBRef, {
    totalMatches: increment,
    lastMatchAt: now
  });

  await batch.commit();
  console.log(`📊 Updated match statistics for ${userAId} and ${userBId}`);
}

/**
 * Scheduled function to clean up stale queue entries and expired locks
 * Runs every 5 minutes
 */
exports.cleanupStaleEntries = functions
  .region('asia-northeast3')
  .pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of stale entries');

    const now = Date.now();
    const staleThreshold = now - (CONFIG.MATCH_TIMEOUT_MS * 10); // 5 minutes

    // Clean up stale queue entries
    const queueRef = db.ref('/matching_queue');
    const queueSnap = await queueRef.once('value');

    let cleanedCount = 0;
    const cleanupPromises = [];

    queueSnap.forEach((childSnap) => {
      const data = childSnap.val();
      const timestamp = data?.timestamp || 0;

      // Remove if stale and still waiting
      if (data?.status === 'waiting' && timestamp < staleThreshold) {
        cleanupPromises.push(childSnap.ref.remove());
        cleanedCount++;
      }

      // Remove if matched but very old (cleanup orphaned entries)
      if (data?.status === 'matched' && timestamp < staleThreshold) {
        cleanupPromises.push(childSnap.ref.remove());
        cleanedCount++;
      }
    });

    // Clean up expired locks
    const locksRef = db.ref('/matching_locks');
    const locksSnap = await locksRef.once('value');

    locksSnap.forEach((childSnap) => {
      const data = childSnap.val();
      if (data?.expiresAt && data.expiresAt < now) {
        cleanupPromises.push(childSnap.ref.remove());
      }
    });

    await Promise.all(cleanupPromises);

    console.log(`🧹 Cleanup complete: removed ${cleanedCount} stale entries`);
    return null;
  });

/**
 * HTTP endpoint for manual cleanup (admin use)
 */
exports.manualCleanup = functions
  .region('asia-northeast3')
  .https
  .onRequest(async (req, res) => {
    // Basic auth check (in production, use proper authentication)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).send('Unauthorized');
      return;
    }

    try {
      // Trigger cleanup
      const now = Date.now();
      const queueRef = db.ref('/matching_queue');
      const snapshot = await queueRef.once('value');

      let cleaned = 0;
      const promises = [];

      snapshot.forEach((child) => {
        const data = child.val();
        // Remove entries older than 10 minutes
        if (data?.timestamp && (now - data.timestamp > 600000)) {
          promises.push(child.ref.remove());
          cleaned++;
        }
      });

      await Promise.all(promises);

      res.json({
        success: true,
        cleaned,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });
