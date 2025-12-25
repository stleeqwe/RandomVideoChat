/**
 * 매칭 시스템 테스트 스크립트
 *
 * 사용법:
 *   node test-matching.js [시나리오]
 *
 * 시나리오:
 *   basic     - 기본 매칭 테스트 (남-여 2명)
 *   gender    - 성별 선호도 테스트 (다양한 조합)
 *   mass      - 대량 유저 테스트 (10명)
 *   cleanup   - 테스트 데이터 정리
 *   watch     - 매칭 결과 실시간 모니터링
 */

const admin = require('firebase-admin');

// Firebase Admin 초기화
const path = require('path');
const os = require('os');
const fs = require('fs');

function initializeFirebase() {
  const databaseURL = 'https://random-video-chat-98e0a-default-rtdb.firebaseio.com';

  // 1. 로컬 서비스 계정 키 시도
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL
    });
    console.log('✅ 서비스 계정 키로 초기화');
    return;
  } catch (e) {}

  // 2. Firebase CLI 토큰 사용 (firebase login 후 생성됨)
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

  // 3. 기본 자격증명
  admin.initializeApp({ databaseURL });
  console.log('⚠️ 기본 자격증명으로 초기화 (권한 제한될 수 있음)');
}

initializeFirebase();

const db = admin.database();
// Firestore는 서비스 계정 키가 필요하므로 Realtime Database만 사용

// 테스트 유저 prefix
const TEST_PREFIX = 'test_user_';

// 색상 출력
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function log(color, ...args) {
  console.log(color, ...args, colors.reset);
}

// ============================================================================
// 테스트 유저 생성
// ============================================================================

function createTestUser(id, gender, preferredGender, preferenceRate = 50) {
  return {
    userId: `${TEST_PREFIX}${id}`,
    status: 'waiting',
    gender: gender,
    preferredGender: preferredGender,
    bucket: `waiting_${gender}`,
    preferenceRate: preferenceRate,
    timestamp: admin.database.ServerValue.TIMESTAMP,
    clientVersion: 'test'
  };
}

async function registerUser(user) {
  const ref = db.ref(`matching_queue/${user.userId}`);
  await ref.set(user);
  log(colors.green, `✅ 등록: ${user.userId} (${user.gender}, 선호: ${user.preferredGender}, 선호도: ${user.preferenceRate}%)`);
  return user.userId;
}

async function registerUsersSequentially(users, delayMs = 500) {
  const registeredIds = [];
  for (const user of users) {
    const id = await registerUser(user);
    registeredIds.push(id);
    if (delayMs > 0) {
      await sleep(delayMs);
    }
  }
  return registeredIds;
}

// ============================================================================
// 시나리오 정의
// ============================================================================

const scenarios = {
  // 기본 매칭: 남자 1명, 여자 1명
  basic: [
    createTestUser('male_1', 'male', 'female'),
    createTestUser('female_1', 'female', 'male')
  ],

  // 성별 선호도 테스트
  gender: [
    createTestUser('m1', 'male', 'female'),      // 남 → 여 선호
    createTestUser('m2', 'male', 'any'),         // 남 → 아무나
    createTestUser('f1', 'female', 'male'),      // 여 → 남 선호
    createTestUser('f2', 'female', 'female'),    // 여 → 여 선호
    createTestUser('m3', 'male', 'male'),        // 남 → 남 선호
  ],

  // 대량 유저 테스트
  mass: [
    createTestUser('m1', 'male', 'female', 80),
    createTestUser('m2', 'male', 'female', 60),
    createTestUser('m3', 'male', 'any', 40),
    createTestUser('m4', 'male', 'male', 70),
    createTestUser('m5', 'male', 'any', 50),
    createTestUser('f1', 'female', 'male', 90),
    createTestUser('f2', 'female', 'male', 30),
    createTestUser('f3', 'female', 'any', 55),
    createTestUser('f4', 'female', 'female', 65),
    createTestUser('f5', 'female', 'any', 45),
  ],

  // 선호도 기반 매칭 테스트
  preference: [
    createTestUser('high_1', 'male', 'female', 95),
    createTestUser('high_2', 'female', 'male', 90),
    createTestUser('mid_1', 'male', 'female', 50),
    createTestUser('mid_2', 'female', 'male', 55),
    createTestUser('low_1', 'male', 'female', 15),
    createTestUser('low_2', 'female', 'male', 20),
  ],

  // 매칭 불가 시나리오 (모두 같은 성별만 선호)
  nomatch: [
    createTestUser('m1', 'male', 'male'),
    createTestUser('m2', 'male', 'male'),
    createTestUser('f1', 'female', 'female'),
    createTestUser('f2', 'female', 'female'),
  ]
};

// ============================================================================
// 매칭 결과 관찰
// ============================================================================

async function watchMatchingResults(userIds, timeoutMs = 30000) {
  log(colors.cyan, '\n👀 매칭 결과 모니터링 시작...\n');

  const results = new Map();
  const startTime = Date.now();

  return new Promise((resolve) => {
    const listeners = [];

    userIds.forEach(userId => {
      const ref = db.ref(`matching_queue/${userId}`);
      const listener = ref.on('value', (snapshot) => {
        const data = snapshot.val();
        if (!data) {
          if (!results.has(userId)) {
            log(colors.yellow, `🗑️  ${userId}: 큐에서 제거됨`);
          }
          return;
        }

        if (data.status === 'matched' && !results.has(userId)) {
          results.set(userId, {
            matchedWith: data.matchedWith,
            channelName: data.channelName,
            matchId: data.matchId
          });

          log(colors.green, `🎯 ${userId} ↔ ${data.matchedWith}`);
          log(colors.blue, `   채널: ${data.channelName}`);
        }
      });
      listeners.push({ ref, listener });
    });

    // 타임아웃
    const timeout = setTimeout(() => {
      listeners.forEach(({ ref, listener }) => ref.off('value', listener));

      log(colors.cyan, '\n📊 매칭 결과 요약:');
      log(colors.cyan, '─'.repeat(50));

      const matched = Array.from(results.entries());
      const unmatched = userIds.filter(id => !results.has(id));

      if (matched.length > 0) {
        log(colors.green, `✅ 매칭됨: ${matched.length}명`);
        matched.forEach(([userId, result]) => {
          log(colors.green, `   ${userId} ↔ ${result.matchedWith}`);
        });
      }

      if (unmatched.length > 0) {
        log(colors.yellow, `⏳ 대기중: ${unmatched.length}명`);
        unmatched.forEach(userId => {
          log(colors.yellow, `   ${userId}`);
        });
      }

      resolve(results);
    }, timeoutMs);

    // 모두 매칭되면 조기 종료
    const checkComplete = setInterval(() => {
      if (results.size >= Math.floor(userIds.length / 2) * 2) {
        clearTimeout(timeout);
        clearInterval(checkComplete);
        listeners.forEach(({ ref, listener }) => ref.off('value', listener));

        log(colors.green, '\n✅ 모든 가능한 매칭 완료!');
        resolve(results);
      }
    }, 500);
  });
}

// ============================================================================
// 정리
// ============================================================================

async function cleanupTestData() {
  log(colors.yellow, '🧹 테스트 데이터 정리 중...\n');

  // matching_queue에서 테스트 유저 제거
  const queueRef = db.ref('matching_queue');
  const queueSnapshot = await queueRef.once('value');
  const queueData = queueSnapshot.val() || {};

  let queueCleanCount = 0;
  for (const userId of Object.keys(queueData)) {
    if (userId.startsWith(TEST_PREFIX)) {
      await db.ref(`matching_queue/${userId}`).remove();
      queueCleanCount++;
    }
  }
  log(colors.green, `✅ matching_queue: ${queueCleanCount}개 제거`);

  // matches에서 테스트 매칭 제거
  const matchesRef = db.ref('matches');
  const matchesSnapshot = await matchesRef.once('value');
  const matchesData = matchesSnapshot.val() || {};

  let matchCleanCount = 0;
  for (const [matchId, match] of Object.entries(matchesData)) {
    if (match.user1?.startsWith(TEST_PREFIX) || match.user2?.startsWith(TEST_PREFIX)) {
      await db.ref(`matches/${matchId}`).remove();
      matchCleanCount++;
    }
  }
  log(colors.green, `✅ matches: ${matchCleanCount}개 제거`);

  // matching_locks 정리
  const locksRef = db.ref('matching_locks');
  await locksRef.remove();
  log(colors.green, `✅ matching_locks: 전체 제거`);

  log(colors.green, '\n🎉 정리 완료!');
}

// ============================================================================
// 현재 상태 출력
// ============================================================================

async function printCurrentState() {
  log(colors.cyan, '\n📋 현재 매칭 큐 상태:\n');

  const snapshot = await db.ref('matching_queue').once('value');
  const data = snapshot.val() || {};

  const users = Object.values(data);

  if (users.length === 0) {
    log(colors.yellow, '   (비어있음)');
    return;
  }

  // 상태별 분류
  const waiting = users.filter(u => u.status === 'waiting');
  const matched = users.filter(u => u.status === 'matched');

  log(colors.blue, `대기중: ${waiting.length}명`);
  waiting.forEach(u => {
    log(colors.reset, `   ${u.userId} (${u.gender} → ${u.preferredGender})`);
  });

  log(colors.green, `\n매칭됨: ${matched.length}명`);
  matched.forEach(u => {
    log(colors.reset, `   ${u.userId} ↔ ${u.matchedWith}`);
  });
}

// ============================================================================
// 유틸리티
// ============================================================================

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function printUsage() {
  console.log(`
${colors.cyan}매칭 시스템 테스트 스크립트${colors.reset}

사용법:
  node test-matching.js [시나리오]

시나리오:
  ${colors.green}basic${colors.reset}      - 기본 매칭 테스트 (남-여 2명)
  ${colors.green}gender${colors.reset}     - 성별 선호도 테스트 (다양한 조합)
  ${colors.green}mass${colors.reset}       - 대량 유저 테스트 (10명)
  ${colors.green}preference${colors.reset} - 선호도 기반 매칭 테스트
  ${colors.green}nomatch${colors.reset}    - 매칭 불가 시나리오
  ${colors.green}cleanup${colors.reset}    - 테스트 데이터 정리
  ${colors.green}status${colors.reset}     - 현재 큐 상태 확인
  ${colors.green}watch${colors.reset}      - 매칭 결과 실시간 모니터링

예시:
  node test-matching.js basic
  node test-matching.js mass
  node test-matching.js cleanup
`);
}

// ============================================================================
// 메인
// ============================================================================

async function main() {
  const scenario = process.argv[2];

  if (!scenario) {
    printUsage();
    process.exit(0);
  }

  try {
    switch (scenario) {
      case 'cleanup':
        await cleanupTestData();
        break;

      case 'status':
        await printCurrentState();
        break;

      case 'watch':
        const snapshot = await db.ref('matching_queue').once('value');
        const data = snapshot.val() || {};
        const allUserIds = Object.keys(data);
        if (allUserIds.length === 0) {
          log(colors.yellow, '큐가 비어있습니다.');
        } else {
          await watchMatchingResults(allUserIds, 60000);
        }
        break;

      default:
        if (!scenarios[scenario]) {
          log(colors.red, `❌ 알 수 없는 시나리오: ${scenario}`);
          printUsage();
          process.exit(1);
        }

        log(colors.cyan, `\n🚀 시나리오 실행: ${scenario}\n`);
        log(colors.cyan, '─'.repeat(50));

        // 기존 테스트 데이터 정리
        await cleanupTestData();
        await sleep(1000);

        // 테스트 유저 등록
        log(colors.cyan, '\n📝 테스트 유저 등록:\n');
        const users = scenarios[scenario];
        const userIds = await registerUsersSequentially(users, 800);

        // 매칭 결과 관찰
        await watchMatchingResults(userIds, 30000);

        // 최종 상태 출력
        await printCurrentState();
    }
  } catch (error) {
    log(colors.red, '❌ 에러:', error.message);
    console.error(error);
  }

  process.exit(0);
}

main();
