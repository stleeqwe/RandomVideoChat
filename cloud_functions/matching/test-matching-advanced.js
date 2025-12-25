/**
 * 고급 매칭 시스템 테스트 스크립트
 *
 * 테스트 시나리오:
 *   1. preference-sort  - 선호도 기반 매칭 (높은 선호도끼리 매칭되는지)
 *   2. requeue          - 통화 종료 후 즉시 재진입 테스트
 *   3. low-preference   - 극단적으로 낮은 선호도 유저 매칭
 *   4. gender-switch    - 성별 선호 변경 후 재진입
 *   5. rapid-requeue    - 빠른 연속 재진입 (스트레스 테스트)
 *   6. mixed-scenario   - 복합 시나리오 (다양한 조건 동시 테스트)
 *   7. queue-priority   - 대기 시간 vs 선호도 우선순위
 *   8. edge-cases       - 엣지 케이스 모음
 *   9. full-simulation  - 전체 시뮬레이션 (실제 사용 패턴)
 *   10. all             - 모든 테스트 순차 실행
 */

const admin = require('firebase-admin');
const path = require('path');
const os = require('os');
const fs = require('fs');

// Firebase Admin 초기화
function initializeFirebase() {
  const databaseURL = 'https://random-video-chat-98e0a-default-rtdb.firebaseio.com';

  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL
    });
    console.log('✅ 서비스 계정 키로 초기화');
    return;
  } catch (e) {}

  const configDir = path.join(os.homedir(), '.config', 'configstore');
  const firebaseToolsPath = path.join(configDir, 'firebase-tools.json');

  try {
    const firebaseConfig = JSON.parse(fs.readFileSync(firebaseToolsPath, 'utf8'));
    const refreshToken = firebaseConfig.tokens?.refresh_token;

    if (refreshToken) {
      admin.initializeApp({
        credential: admin.credential.refreshToken({
          type: 'authorized_user',
          client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
          client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
          refresh_token: refreshToken
        }),
        databaseURL
      });
      console.log('✅ Firebase CLI 토큰으로 초기화');
      return;
    }
  } catch (e) {}

  admin.initializeApp({ databaseURL });
  console.log('⚠️ 기본 자격증명으로 초기화');
}

initializeFirebase();

const db = admin.database();
const TEST_PREFIX = 'adv_test_';

// 색상 출력
const c = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  bold: '\x1b[1m',
  dim: '\x1b[2m'
};

function log(color, ...args) {
  console.log(color, ...args, c.reset);
}

function header(title) {
  console.log('\n' + c.cyan + c.bold + '═'.repeat(60) + c.reset);
  console.log(c.cyan + c.bold + '  ' + title + c.reset);
  console.log(c.cyan + c.bold + '═'.repeat(60) + c.reset + '\n');
}

function subheader(title) {
  console.log('\n' + c.blue + '── ' + title + ' ' + '─'.repeat(40) + c.reset + '\n');
}

// ============================================================================
// 유틸리티
// ============================================================================

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function createUser(id, gender, preferredGender, preferenceRate = 50, extraFields = {}) {
  return {
    userId: `${TEST_PREFIX}${id}`,
    status: 'waiting',
    gender: gender,
    preferredGender: preferredGender,
    bucket: `waiting_${gender}`,
    preferenceRate: preferenceRate,
    timestamp: admin.database.ServerValue.TIMESTAMP,
    clientVersion: 'test-advanced',
    ...extraFields
  };
}

async function registerUser(user) {
  const ref = db.ref(`matching_queue/${user.userId}`);
  await ref.set(user);
  log(c.green, `  ✅ 등록: ${user.userId} (${user.gender}, 선호:${user.preferredGender}, 선호도:${user.preferenceRate}%)`);
  return user.userId;
}

async function registerUsers(users, delayMs = 300) {
  const ids = [];
  for (const user of users) {
    const id = await registerUser(user);
    ids.push(id);
    if (delayMs > 0) await sleep(delayMs);
  }
  return ids;
}

async function removeUser(userId) {
  await db.ref(`matching_queue/${userId}`).remove();
  log(c.yellow, `  🗑️  제거: ${userId}`);
}

async function updateUser(userId, updates) {
  await db.ref(`matching_queue/${userId}`).update(updates);
  log(c.blue, `  📝 업데이트: ${userId} → ${JSON.stringify(updates)}`);
}

async function simulateCallEnd(userId) {
  // 통화 종료 시뮬레이션: 큐에서 제거
  await db.ref(`matching_queue/${userId}`).remove();
  log(c.magenta, `  📞 통화 종료: ${userId}`);
}

async function reenterQueue(user) {
  // 상태 초기화하고 재진입
  user.status = 'waiting';
  user.matchedWith = null;
  user.channelName = null;
  user.matchId = null;
  user.timestamp = admin.database.ServerValue.TIMESTAMP;

  const ref = db.ref(`matching_queue/${user.userId}`);
  await ref.set(user);
  log(c.cyan, `  🔄 재진입: ${user.userId}`);
  return user.userId;
}

async function getQueueSnapshot() {
  const snapshot = await db.ref('matching_queue').once('value');
  return snapshot.val() || {};
}

async function getUserStatus(userId) {
  const snapshot = await db.ref(`matching_queue/${userId}`).once('value');
  return snapshot.val();
}

async function cleanupTestData() {
  log(c.yellow, '\n🧹 테스트 데이터 정리 중...');

  const queueSnapshot = await db.ref('matching_queue').once('value');
  const queueData = queueSnapshot.val() || {};

  let queueCount = 0;
  for (const userId of Object.keys(queueData)) {
    if (userId.startsWith(TEST_PREFIX)) {
      await db.ref(`matching_queue/${userId}`).remove();
      queueCount++;
    }
  }

  const matchesSnapshot = await db.ref('matches').once('value');
  const matchesData = matchesSnapshot.val() || {};

  let matchCount = 0;
  for (const [matchId, match] of Object.entries(matchesData)) {
    if (match.user1?.startsWith(TEST_PREFIX) || match.user2?.startsWith(TEST_PREFIX)) {
      await db.ref(`matches/${matchId}`).remove();
      matchCount++;
    }
  }

  await db.ref('matching_locks').remove();

  log(c.green, `  ✅ 정리 완료 (큐: ${queueCount}, 매칭: ${matchCount})`);
}

async function watchMatching(userIds, timeoutMs = 20000) {
  return new Promise((resolve) => {
    const results = new Map();
    const listeners = [];
    const startTime = Date.now();

    userIds.forEach(userId => {
      const ref = db.ref(`matching_queue/${userId}`);
      const listener = ref.on('value', (snapshot) => {
        const data = snapshot.val();
        if (!data) return;

        if (data.status === 'matched' && !results.has(userId)) {
          results.set(userId, {
            matchedWith: data.matchedWith,
            channelName: data.channelName,
            time: Date.now() - startTime
          });
          log(c.green, `  🎯 ${userId.replace(TEST_PREFIX, '')} ↔ ${data.matchedWith?.replace(TEST_PREFIX, '')} (${Date.now() - startTime}ms)`);
        }
      });
      listeners.push({ ref, listener });
    });

    const timeout = setTimeout(() => {
      listeners.forEach(({ ref, listener }) => ref.off('value', listener));
      resolve(results);
    }, timeoutMs);

    const checkComplete = setInterval(() => {
      if (results.size >= Math.floor(userIds.length / 2) * 2) {
        clearTimeout(timeout);
        clearInterval(checkComplete);
        listeners.forEach(({ ref, listener }) => ref.off('value', listener));
        resolve(results);
      }
    }, 200);
  });
}

function analyzeResults(results, users, testName) {
  console.log('\n' + c.cyan + '📊 결과 분석: ' + testName + c.reset);
  console.log(c.dim + '─'.repeat(50) + c.reset);

  const matched = Array.from(results.entries());
  const matchedIds = new Set(matched.map(([id]) => id));
  const unmatched = users.filter(u => !matchedIds.has(u.userId));

  log(c.green, `  매칭됨: ${matched.length}명`);
  log(c.yellow, `  대기중: ${unmatched.length}명`);

  // 매칭 품질 분석
  const pairs = [];
  const seen = new Set();
  for (const [userId, result] of matched) {
    if (!seen.has(userId) && !seen.has(result.matchedWith)) {
      const user1 = users.find(u => u.userId === userId);
      const user2 = users.find(u => u.userId === result.matchedWith);
      if (user1 && user2) {
        pairs.push({ user1, user2, time: result.time });
        seen.add(userId);
        seen.add(result.matchedWith);
      }
    }
  }

  if (pairs.length > 0) {
    console.log('\n  매칭 상세:');
    pairs.forEach(({ user1, user2, time }) => {
      const prefDiff = Math.abs(user1.preferenceRate - user2.preferenceRate);
      const prefAvg = (user1.preferenceRate + user2.preferenceRate) / 2;
      const genderMatch = checkGenderPreference(user1, user2);

      console.log(`    ${user1.userId.replace(TEST_PREFIX, '')} (${user1.preferenceRate}%) ↔ ${user2.userId.replace(TEST_PREFIX, '')
      } (${user2.preferenceRate}%)`);
      console.log(`      선호도차: ${prefDiff}%, 평균: ${prefAvg}%, 성별호환: ${genderMatch ? '✅' : '❌'}, 시간: ${time}ms`);
    });
  }

  return { matched: matched.length, unmatched: unmatched.length, pairs };
}

function checkGenderPreference(user1, user2) {
  const u1AcceptsU2 = user1.preferredGender === 'any' || user1.preferredGender === user2.gender;
  const u2AcceptsU1 = user2.preferredGender === 'any' || user2.preferredGender === user1.gender;
  return u1AcceptsU2 && u2AcceptsU1;
}

// ============================================================================
// 테스트 시나리오
// ============================================================================

async function testPreferenceSort() {
  header('테스트 1: 선호도 기반 매칭');
  console.log('높은 선호도 유저끼리, 낮은 선호도 유저끼리 매칭되는지 확인\n');

  await cleanupTestData();
  await sleep(500);

  const users = [
    // 높은 선호도 그룹
    createUser('high_m1', 'male', 'female', 95),
    createUser('high_f1', 'female', 'male', 92),
    createUser('high_m2', 'male', 'female', 88),
    createUser('high_f2', 'female', 'male', 85),
    // 중간 선호도 그룹
    createUser('mid_m1', 'male', 'female', 55),
    createUser('mid_f1', 'female', 'male', 52),
    createUser('mid_m2', 'male', 'female', 48),
    createUser('mid_f2', 'female', 'male', 45),
    // 낮은 선호도 그룹
    createUser('low_m1', 'male', 'female', 15),
    createUser('low_f1', 'female', 'male', 12),
    createUser('low_m2', 'male', 'female', 8),
    createUser('low_f2', 'female', 'male', 5),
  ];

  subheader('유저 등록 (동시에 큐 진입)');
  const userIds = await registerUsers(users, 100);

  subheader('매칭 결과 대기');
  const results = await watchMatching(userIds, 25000);

  const analysis = analyzeResults(results, users, '선호도 기반 매칭');

  // 검증: 높은 선호도끼리 매칭되었는지
  let highWithHigh = 0;
  let lowWithLow = 0;

  for (const { user1, user2 } of analysis.pairs) {
    const avg = (user1.preferenceRate + user2.preferenceRate) / 2;
    if (avg >= 80) highWithHigh++;
    if (avg <= 20) lowWithLow++;
  }

  console.log('\n' + c.bold + '검증 결과:' + c.reset);
  console.log(`  높은 선호도 매칭 (평균 80%+): ${highWithHigh}쌍`);
  console.log(`  낮은 선호도 매칭 (평균 20%-): ${lowWithLow}쌍`);

  return analysis;
}

async function testRequeue() {
  header('테스트 2: 통화 종료 후 즉시 재진입');
  console.log('통화 종료 후 큐에 재진입했을 때 기존 대기자와 매칭되는지 확인\n');

  await cleanupTestData();
  await sleep(500);

  // 1단계: 초기 유저들 등록
  subheader('1단계: 초기 유저 등록');
  const waitingUsers = [
    createUser('waiting_m1', 'male', 'female', 60),
    createUser('waiting_f1', 'female', 'male', 55),
  ];
  const waitingIds = await registerUsers(waitingUsers, 200);

  log(c.cyan, '\n  ⏳ 2초 대기 (큐에 머무르게 함)...');
  await sleep(2000);

  // 2단계: 통화 중이던 유저가 종료 후 재진입
  subheader('2단계: 통화 종료 후 재진입 유저');
  const reentryUser = createUser('reentry_m1', 'male', 'female', 70);
  reentryUser.previousMatch = 'some_user_id'; // 이전 통화 상대 기록

  const reentryId = await registerUser(reentryUser);

  // 모든 유저 모니터링
  const allIds = [...waitingIds, reentryId];

  subheader('매칭 결과 대기');
  const results = await watchMatching(allIds, 15000);

  analyzeResults(results, [...waitingUsers, reentryUser], '재진입 테스트');

  // 재진입 유저가 매칭되었는지 확인
  const reentryMatched = results.has(reentryId);
  console.log('\n' + c.bold + '검증 결과:' + c.reset);
  console.log(`  재진입 유저 매칭: ${reentryMatched ? '✅ 성공' : '❌ 실패'}`);

  return { reentryMatched };
}

async function testLowPreference() {
  header('테스트 3: 극단적으로 낮은 선호도 유저');
  console.log('선호도 1%, 0%인 유저도 매칭이 되는지 확인\n');

  await cleanupTestData();
  await sleep(500);

  const users = [
    createUser('ultra_low_m', 'male', 'female', 1),
    createUser('ultra_low_f', 'female', 'male', 0),
    createUser('zero_m', 'male', 'any', 0),
    createUser('zero_f', 'female', 'any', 0),
    createUser('normal_m', 'male', 'female', 50),
    createUser('normal_f', 'female', 'male', 50),
  ];

  subheader('유저 등록');
  const userIds = await registerUsers(users, 300);

  subheader('매칭 결과 대기');
  const results = await watchMatching(userIds, 20000);

  const analysis = analyzeResults(results, users, '낮은 선호도 테스트');

  // 0% 유저들도 매칭되었는지 확인
  const zeroUsers = users.filter(u => u.preferenceRate === 0);
  const zeroMatched = zeroUsers.filter(u => results.has(u.userId)).length;

  console.log('\n' + c.bold + '검증 결과:' + c.reset);
  console.log(`  선호도 0% 유저: ${zeroUsers.length}명 중 ${zeroMatched}명 매칭됨`);
  console.log(`  결과: ${zeroMatched === zeroUsers.length ? '✅ 모두 매칭' : zeroMatched > 0 ? '⚠️ 일부 매칭' : '❌ 매칭 실패'}`);

  return { zeroMatched, zeroTotal: zeroUsers.length };
}

async function testGenderSwitch() {
  header('테스트 4: 성별 선호 변경 후 재진입');
  console.log('유저가 성별 선호를 변경하고 재진입했을 때 새 설정대로 매칭되는지 확인\n');

  await cleanupTestData();
  await sleep(500);

  // 1단계: 초기 설정
  subheader('1단계: 초기 유저 등록');
  let switchUser = createUser('switch_m', 'male', 'female', 60);
  const otherUsers = [
    createUser('other_m1', 'male', 'any', 55),
    createUser('other_f1', 'female', 'male', 50),
  ];

  await registerUsers([switchUser, ...otherUsers], 200);

  log(c.cyan, '\n  ⏳ 매칭 대기...');
  await sleep(3000);

  // 매칭 확인
  let status = await getUserStatus(switchUser.userId);
  if (status?.status === 'matched') {
    log(c.green, `  첫 번째 매칭: ${switchUser.userId} ↔ ${status.matchedWith}`);

    // 2단계: 통화 종료 및 성별 선호 변경
    subheader('2단계: 성별 선호 변경 후 재진입');
    await simulateCallEnd(switchUser.userId);
    await sleep(500);

    // 성별 선호 변경: female → male
    switchUser.preferredGender = 'male';
    switchUser.status = 'waiting';
    switchUser.matchedWith = null;

    // 새로운 상대 등록
    const newPartner = createUser('new_m2', 'male', 'male', 65);
    await registerUser(newPartner);
    await sleep(300);

    await reenterQueue(switchUser);

    subheader('변경 후 매칭 결과 대기');
    const results = await watchMatching([switchUser.userId, newPartner.userId], 15000);

    status = await getUserStatus(switchUser.userId);
    if (status?.status === 'matched') {
      const matchedPartner = status.matchedWith;
      const partnerData = await getUserStatus(matchedPartner);

      console.log('\n' + c.bold + '검증 결과:' + c.reset);
      console.log(`  새 매칭 상대: ${matchedPartner}`);
      console.log(`  상대 성별: ${partnerData?.gender}`);
      console.log(`  선호 변경 적용: ${partnerData?.gender === 'male' ? '✅ 성공' : '❌ 실패'}`);
    }
  } else {
    log(c.yellow, '  첫 번째 매칭 대기 중 (추가 대기 필요)');
  }
}

async function testRapidRequeue() {
  header('테스트 5: 빠른 연속 재진입 (스트레스 테스트)');
  console.log('여러 유저가 빠르게 통화 종료/재진입을 반복할 때 시스템 안정성 확인\n');

  await cleanupTestData();
  await sleep(500);

  const users = [];
  for (let i = 1; i <= 6; i++) {
    users.push(createUser(`rapid_m${i}`, 'male', 'female', 40 + i * 5));
    users.push(createUser(`rapid_f${i}`, 'female', 'male', 40 + i * 5));
  }

  subheader('초기 등록');
  await registerUsers(users, 100);

  log(c.cyan, '\n  ⏳ 첫 매칭 대기 (5초)...');
  await sleep(5000);

  // 매칭된 유저들 확인 후 일부 재진입
  subheader('재진입 사이클 시작');

  for (let cycle = 1; cycle <= 3; cycle++) {
    log(c.magenta, `\n  📌 사이클 ${cycle}/3`);

    const queue = await getQueueSnapshot();
    const matchedUsers = Object.entries(queue)
      .filter(([id, data]) => id.startsWith(TEST_PREFIX) && data.status === 'matched')
      .slice(0, 4);

    if (matchedUsers.length === 0) {
      log(c.yellow, '    매칭된 유저 없음, 대기 중...');
      await sleep(2000);
      continue;
    }

    // 빠르게 재진입
    for (const [userId, data] of matchedUsers) {
      await db.ref(`matching_queue/${userId}`).update({
        status: 'waiting',
        matchedWith: null,
        channelName: null,
        timestamp: admin.database.ServerValue.TIMESTAMP
      });
      log(c.cyan, `    🔄 재진입: ${userId.replace(TEST_PREFIX, '')}`);
      await sleep(50); // 매우 빠른 재진입
    }

    await sleep(3000); // 매칭 대기
  }

  subheader('최종 상태 확인');
  const finalQueue = await getQueueSnapshot();
  const testUsers = Object.entries(finalQueue)
    .filter(([id]) => id.startsWith(TEST_PREFIX));

  const matched = testUsers.filter(([, data]) => data.status === 'matched').length;
  const waiting = testUsers.filter(([, data]) => data.status === 'waiting').length;

  console.log('\n' + c.bold + '검증 결과:' + c.reset);
  console.log(`  총 유저: ${testUsers.length}명`);
  console.log(`  매칭됨: ${matched}명`);
  console.log(`  대기중: ${waiting}명`);
  console.log(`  시스템 안정성: ${testUsers.length > 0 ? '✅' : '⚠️'}`);
}

async function testMixedScenario() {
  header('테스트 6: 복합 시나리오');
  console.log('다양한 조건의 유저들이 동시에 존재할 때 전체 매칭 동작 확인\n');

  await cleanupTestData();
  await sleep(500);

  const users = [
    // 높은 선호도 + 이성 선호
    createUser('mix_high_m1', 'male', 'female', 90),
    createUser('mix_high_f1', 'female', 'male', 88),

    // 높은 선호도 + 동성 선호
    createUser('mix_high_m2', 'male', 'male', 85),
    createUser('mix_high_m3', 'male', 'male', 82),

    // 중간 선호도 + any
    createUser('mix_mid_m1', 'male', 'any', 50),
    createUser('mix_mid_f1', 'female', 'any', 48),

    // 낮은 선호도 + 이성 선호
    createUser('mix_low_m1', 'male', 'female', 10),
    createUser('mix_low_f1', 'female', 'male', 8),

    // 여성 + 여성 선호
    createUser('mix_ff1', 'female', 'female', 60),
    createUser('mix_ff2', 'female', 'female', 55),

    // 불균형 (남성 초과)
    createUser('mix_extra_m1', 'male', 'female', 40),
    createUser('mix_extra_m2', 'male', 'female', 35),
  ];

  subheader('복합 조건 유저 등록');
  const userIds = await registerUsers(users, 150);

  subheader('매칭 결과 대기');
  const results = await watchMatching(userIds, 25000);

  const analysis = analyzeResults(results, users, '복합 시나리오');

  // 상세 분석
  console.log('\n' + c.bold + '매칭 품질 분석:' + c.reset);

  let genderCompatible = 0;
  let prefWithin20 = 0;

  for (const { user1, user2 } of analysis.pairs) {
    if (checkGenderPreference(user1, user2)) genderCompatible++;
    if (Math.abs(user1.preferenceRate - user2.preferenceRate) <= 20) prefWithin20++;
  }

  console.log(`  성별 호환 매칭: ${genderCompatible}/${analysis.pairs.length}`);
  console.log(`  선호도 차이 20% 이내: ${prefWithin20}/${analysis.pairs.length}`);
}

async function testQueuePriority() {
  header('테스트 7: 대기 시간 vs 선호도 우선순위');
  console.log('오래 기다린 유저 vs 높은 선호도 유저 중 누가 먼저 매칭되는지 확인\n');

  await cleanupTestData();
  await sleep(500);

  // 1단계: 낮은 선호도 유저가 먼저 대기
  subheader('1단계: 낮은 선호도 유저 먼저 등록');
  const earlyUser = createUser('early_low_m', 'male', 'female', 20);
  await registerUser(earlyUser);

  log(c.cyan, '  ⏳ 3초 대기 (대기 시간 확보)...');
  await sleep(3000);

  // 2단계: 높은 선호도 유저 나중에 등록
  subheader('2단계: 높은 선호도 유저 나중에 등록');
  const lateUser = createUser('late_high_m', 'male', 'female', 95);
  await registerUser(lateUser);
  await sleep(300);

  // 3단계: 여성 유저 등록 (한 명만)
  subheader('3단계: 여성 유저 등록 (1명)');
  const femaleUser = createUser('target_f', 'female', 'male', 60);
  await registerUser(femaleUser);

  subheader('매칭 결과 대기');
  const results = await watchMatching([earlyUser.userId, lateUser.userId, femaleUser.userId], 15000);

  // 누가 매칭되었는지 확인
  const femaleStatus = await getUserStatus(femaleUser.userId);

  console.log('\n' + c.bold + '검증 결과:' + c.reset);
  if (femaleStatus?.status === 'matched') {
    const matchedWith = femaleStatus.matchedWith;
    if (matchedWith === earlyUser.userId) {
      console.log('  여성 ↔ 먼저 온 유저 (낮은 선호도)');
      console.log('  📌 결론: 대기 시간 우선 (FIFO)');
    } else if (matchedWith === lateUser.userId) {
      console.log('  여성 ↔ 나중에 온 유저 (높은 선호도)');
      console.log('  📌 결론: 선호도 우선');
    }
  } else {
    console.log('  아직 매칭 안됨');
  }
}

async function testEdgeCases() {
  header('테스트 8: 엣지 케이스 모음');
  console.log('특이한 상황들에서의 동작 확인\n');

  await cleanupTestData();
  await sleep(500);

  // 케이스 1: 동일한 유저 ID 중복 등록 시도
  subheader('케이스 1: 중복 등록 시도');
  const dupUser = createUser('dup_user', 'male', 'female', 50);
  await registerUser(dupUser);
  await sleep(200);
  dupUser.preferenceRate = 99; // 다른 값으로 재등록 시도
  await registerUser(dupUser);

  const dupStatus = await getUserStatus(dupUser.userId);
  console.log(`  결과: preferenceRate = ${dupStatus?.preferenceRate}% (99면 덮어쓰기됨)`);

  // 케이스 2: 선호도 100%
  subheader('케이스 2: 선호도 100%');
  const perfectUser = createUser('perfect_m', 'male', 'female', 100);
  const partnerUser = createUser('perfect_f', 'female', 'male', 100);
  await registerUsers([perfectUser, partnerUser], 200);

  await sleep(3000);
  const perfectStatus = await getUserStatus(perfectUser.userId);
  console.log(`  100% 유저 매칭: ${perfectStatus?.status === 'matched' ? '✅' : '❌'}`);

  // 케이스 3: 자기 자신과 매칭 방지
  subheader('케이스 3: 자기 자신 매칭 방지 확인');
  const singleUser = createUser('alone', 'male', 'any', 50);
  await registerUser(singleUser);

  await sleep(3000);
  const singleStatus = await getUserStatus(singleUser.userId);
  console.log(`  혼자 있는 유저 상태: ${singleStatus?.status} (waiting이어야 정상)`);

  // 케이스 4: 특수 문자가 포함된 케이스 (실제로는 userId에 특수문자 없음)
  subheader('케이스 4: 숫자만 있는 ID');
  const numUser1 = createUser('123', 'male', 'female', 50);
  const numUser2 = createUser('456', 'female', 'male', 50);
  await registerUsers([numUser1, numUser2], 200);

  await sleep(3000);
  const numStatus = await getUserStatus(numUser1.userId);
  console.log(`  숫자 ID 매칭: ${numStatus?.status === 'matched' ? '✅' : '❌'}`);
}

async function testFullSimulation() {
  header('테스트 9: 전체 시뮬레이션 (실제 사용 패턴)');
  console.log('실제 앱 사용 패턴을 시뮬레이션하여 전체 흐름 테스트\n');

  await cleanupTestData();
  await sleep(500);

  const stats = {
    totalMatches: 0,
    avgMatchTime: 0,
    matchTimes: [],
    cycles: 0
  };

  // 시뮬레이션 파라미터
  const TOTAL_USERS = 10;
  const SIMULATION_CYCLES = 3;
  const CALL_DURATION_MS = 2000; // 통화 시간 시뮬레이션

  // 초기 유저 풀 생성
  const userPool = [];
  for (let i = 1; i <= TOTAL_USERS / 2; i++) {
    userPool.push({
      ...createUser(`sim_m${i}`, 'male', i % 3 === 0 ? 'any' : 'female', 20 + Math.random() * 60),
      isInCall: false
    });
    userPool.push({
      ...createUser(`sim_f${i}`, 'female', i % 3 === 0 ? 'any' : 'male', 20 + Math.random() * 60),
      isInCall: false
    });
  }

  for (let cycle = 1; cycle <= SIMULATION_CYCLES; cycle++) {
    subheader(`시뮬레이션 사이클 ${cycle}/${SIMULATION_CYCLES}`);

    // 대기 중인 유저들 큐에 등록
    const availableUsers = userPool.filter(u => !u.isInCall);
    log(c.blue, `  대기 가능 유저: ${availableUsers.length}명`);

    const startTime = Date.now();

    for (const user of availableUsers) {
      user.timestamp = admin.database.ServerValue.TIMESTAMP;
      user.status = 'waiting';
      user.matchedWith = null;
      await db.ref(`matching_queue/${user.userId}`).set(user);
    }

    // 매칭 대기
    log(c.cyan, '  ⏳ 매칭 대기...');
    await sleep(5000);

    // 매칭 결과 확인
    const queue = await getQueueSnapshot();
    let matchedThisCycle = 0;

    for (const user of userPool) {
      const data = queue[user.userId];
      if (data?.status === 'matched') {
        user.isInCall = true;
        matchedThisCycle++;
        stats.matchTimes.push(Date.now() - startTime);
      }
    }

    stats.totalMatches += matchedThisCycle / 2; // 쌍으로 카운트
    log(c.green, `  이번 사이클 매칭: ${matchedThisCycle / 2}쌍`);

    // 통화 시뮬레이션
    log(c.magenta, `  📞 통화 중... (${CALL_DURATION_MS}ms)`);
    await sleep(CALL_DURATION_MS);

    // 일부 유저 통화 종료
    const inCallUsers = userPool.filter(u => u.isInCall);
    const endingCount = Math.ceil(inCallUsers.length * 0.7); // 70% 통화 종료

    for (let i = 0; i < endingCount && i < inCallUsers.length; i++) {
      inCallUsers[i].isInCall = false;
      await db.ref(`matching_queue/${inCallUsers[i].userId}`).remove();
    }

    log(c.yellow, `  ${endingCount}명 통화 종료`);
    stats.cycles++;
  }

  // 최종 결과
  subheader('시뮬레이션 결과');
  stats.avgMatchTime = stats.matchTimes.length > 0
    ? Math.round(stats.matchTimes.reduce((a, b) => a + b, 0) / stats.matchTimes.length)
    : 0;

  console.log('\n' + c.bold + '📊 통계:' + c.reset);
  console.log(`  총 사이클: ${stats.cycles}`);
  console.log(`  총 매칭 수: ${stats.totalMatches}쌍`);
  console.log(`  평균 매칭 시간: ${stats.avgMatchTime}ms`);
  console.log(`  사이클당 평균 매칭: ${(stats.totalMatches / stats.cycles).toFixed(1)}쌍`);

  await cleanupTestData();
}

async function runAllTests() {
  header('🚀 전체 테스트 실행');

  const results = [];

  try {
    await testPreferenceSort();
    results.push({ name: '선호도 기반 매칭', status: '✅' });
  } catch (e) {
    results.push({ name: '선호도 기반 매칭', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testRequeue();
    results.push({ name: '통화 후 재진입', status: '✅' });
  } catch (e) {
    results.push({ name: '통화 후 재진입', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testLowPreference();
    results.push({ name: '낮은 선호도 매칭', status: '✅' });
  } catch (e) {
    results.push({ name: '낮은 선호도 매칭', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testGenderSwitch();
    results.push({ name: '성별 선호 변경', status: '✅' });
  } catch (e) {
    results.push({ name: '성별 선호 변경', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testRapidRequeue();
    results.push({ name: '빠른 재진입', status: '✅' });
  } catch (e) {
    results.push({ name: '빠른 재진입', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testMixedScenario();
    results.push({ name: '복합 시나리오', status: '✅' });
  } catch (e) {
    results.push({ name: '복합 시나리오', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testQueuePriority();
    results.push({ name: '우선순위 테스트', status: '✅' });
  } catch (e) {
    results.push({ name: '우선순위 테스트', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testEdgeCases();
    results.push({ name: '엣지 케이스', status: '✅' });
  } catch (e) {
    results.push({ name: '엣지 케이스', status: '❌', error: e.message });
  }
  await sleep(1000);

  try {
    await testFullSimulation();
    results.push({ name: '전체 시뮬레이션', status: '✅' });
  } catch (e) {
    results.push({ name: '전체 시뮬레이션', status: '❌', error: e.message });
  }

  // 최종 결과 요약
  header('📋 전체 테스트 결과');
  results.forEach(r => {
    console.log(`  ${r.status} ${r.name}${r.error ? ` - ${r.error}` : ''}`);
  });

  const passed = results.filter(r => r.status === '✅').length;
  console.log(`\n  총 ${results.length}개 중 ${passed}개 통과`);

  await cleanupTestData();
}

// ============================================================================
// 메인
// ============================================================================

function printUsage() {
  console.log(`
${c.cyan}${c.bold}고급 매칭 시스템 테스트${c.reset}

사용법:
  node test-matching-advanced.js [시나리오]

시나리오:
  ${c.green}preference-sort${c.reset}  - 선호도 기반 매칭 테스트
  ${c.green}requeue${c.reset}          - 통화 종료 후 재진입 테스트
  ${c.green}low-preference${c.reset}   - 극단적으로 낮은 선호도 테스트
  ${c.green}gender-switch${c.reset}    - 성별 선호 변경 후 재진입
  ${c.green}rapid-requeue${c.reset}    - 빠른 연속 재진입 (스트레스)
  ${c.green}mixed-scenario${c.reset}   - 복합 시나리오
  ${c.green}queue-priority${c.reset}   - 대기시간 vs 선호도 우선순위
  ${c.green}edge-cases${c.reset}       - 엣지 케이스 모음
  ${c.green}full-simulation${c.reset}  - 전체 사용 패턴 시뮬레이션
  ${c.green}all${c.reset}              - 모든 테스트 순차 실행
  ${c.green}cleanup${c.reset}          - 테스트 데이터 정리

예시:
  node test-matching-advanced.js preference-sort
  node test-matching-advanced.js all
`);
}

async function main() {
  const scenario = process.argv[2];

  if (!scenario) {
    printUsage();
    process.exit(0);
  }

  try {
    switch (scenario) {
      case 'preference-sort':
        await testPreferenceSort();
        break;
      case 'requeue':
        await testRequeue();
        break;
      case 'low-preference':
        await testLowPreference();
        break;
      case 'gender-switch':
        await testGenderSwitch();
        break;
      case 'rapid-requeue':
        await testRapidRequeue();
        break;
      case 'mixed-scenario':
        await testMixedScenario();
        break;
      case 'queue-priority':
        await testQueuePriority();
        break;
      case 'edge-cases':
        await testEdgeCases();
        break;
      case 'full-simulation':
        await testFullSimulation();
        break;
      case 'all':
        await runAllTests();
        break;
      case 'cleanup':
        await cleanupTestData();
        break;
      default:
        log(c.red, `❌ 알 수 없는 시나리오: ${scenario}`);
        printUsage();
        process.exit(1);
    }
  } catch (error) {
    log(c.red, '❌ 에러:', error.message);
    console.error(error);
  }

  await cleanupTestData();
  process.exit(0);
}

main();
