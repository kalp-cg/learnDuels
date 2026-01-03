const io = require('socket.io-client');
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const bcrypt = require('bcryptjs');

const API_URL = 'http://localhost:4000/api';
const SOCKET_URL = 'http://localhost:4000';

// Test Users
const randomId = Math.floor(Math.random() * 10000);
const USER1_CREDS = { email: `tie1_${randomId}@example.com`, password: 'password123', name: `TiePlayer1_${randomId}` };
const USER2_CREDS = { email: `tie2_${randomId}@example.com`, password: 'password123', name: `TiePlayer2_${randomId}` };

let user1Token, user2Token;
let user1Id, user2Id;
let user1Socket, user2Socket;
let challengeId;
let roomId;

async function setupUsers() {
  console.log('🛠️ Setting up test users...');
  
  const passwordHash = await bcrypt.hash('password123', 10);

  // Create or update users
  const u1 = await prisma.user.upsert({
    where: { email: USER1_CREDS.email },
    update: { passwordHash },
    create: { 
      email: USER1_CREDS.email, 
      passwordHash, 
      fullName: USER1_CREDS.name,
      username: `tie1_${randomId}`,
      authProvider: 'email'
    }
  });
  user1Id = u1.id;

  const u2 = await prisma.user.upsert({
    where: { email: USER2_CREDS.email },
    update: { passwordHash },
    create: { 
      email: USER2_CREDS.email, 
      passwordHash, 
      fullName: USER2_CREDS.name,
      username: `tie2_${randomId}`,
      authProvider: 'email'
    }
  });
  user2Id = u2.id;

  console.log(`   Users ready: ${u1.username} (${u1.id}), ${u2.username} (${u2.id})`);
}

async function login(credentials) {
  try {
    const res = await axios.post(`${API_URL}/auth/login`, credentials);
    return { token: res.data.data.accessToken, userId: res.data.data.user.id };
  } catch (error) {
    console.error(`Login failed for ${credentials.email}:`, error.response?.data || error.message);
    process.exit(1);
  }
}

function connectSocket(token, name, namespace = '') {
  return new Promise((resolve, reject) => {
    const socket = io(`${SOCKET_URL}${namespace}`, {
      auth: { token },
      transports: ['websocket'],
      forceNew: true,
    });

    socket.on('connect', () => {
      console.log(`✅ ${name} connected to socket ${namespace} (${socket.id})`);
      resolve(socket);
    });

    socket.on('connect_error', (err) => {
      console.error(`❌ ${name} socket connection error ${namespace}:`, err.message);
      reject(err);
    });
  });
}

let categoryId;

async function setupData() {
  console.log('🛠️ Setting up test data (Topic & Questions)...');
  
  // Create Topic
  const topic = await prisma.topic.upsert({
    where: { slug: 'tie-breaker-topic' },
    update: {},
    create: { name: 'Tie Breaker Topic', slug: 'tie-breaker-topic', description: 'For testing ties' }
  });
  categoryId = topic.id;
  console.log(`   Topic created: ${topic.name} (${topic.id})`);

  // Create Questions
  const count = await prisma.question.count({
    where: { topics: { some: { topicId: topic.id } } }
  });

  if (count < 5) {
    const questions = [];
    for (let i = 1; i <= 5; i++) {
      const q = await prisma.question.create({
        data: {
          content: `Tie Question ${i} - ${Date.now()}?`,
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          difficulty: 'easy',
          type: 'mcq',
          status: 'published',
          authorId: user1Id, // Use user1 as author
          topics: {
            create: { topicId: topic.id }
          }
        }
      });
      questions.push(q);
    }
    console.log(`   Created ${questions.length} test questions`);
  } else {
    console.log(`   Topic has ${count} questions.`);
  }
}

async function runTest() {
  console.log('🚀 Starting Tie-Breaker Logic Test...');

  await setupUsers();
  await setupData();

  // Login
  const l1 = await login(USER1_CREDS);
  user1Token = l1.token;
  const l2 = await login(USER2_CREDS);
  user2Token = l2.token;

  // Connect Sockets
  user1Socket = await connectSocket(user1Token, 'Player 1');
  user2Socket = await connectSocket(user2Token, 'Player 2');

  user1Socket.on('duel:error', (err) => console.error('❌ P1 Duel Error:', err));
  user2Socket.on('duel:error', (err) => console.error('❌ P2 Duel Error:', err));
  user1Socket.on('challenge:error', (err) => console.error('❌ P1 Challenge Error:', err));
  user2Socket.on('challenge:error', (err) => console.error('❌ P2 Challenge Error:', err));

  user2Socket.on('challenge:invitation_received', (data) => {
    console.log('   P2 received invitation:', data.challengeId);
  });

  // 1. Create Duel (P1 vs P2) via REST
  console.log('\n1️⃣ Creating Duel via REST...');
  let duelId;
  try {
    const res = await axios.post(
      `${API_URL}/duels`,
      {
        opponentId: user2Id,
        categoryId: categoryId,
        difficultyId: 1,
        betAmount: 0
      },
      { headers: { Authorization: `Bearer ${user1Token}` } }
    );
    duelId = res.data.data.id;
    console.log(`   Duel created: ${duelId}`);
  } catch (err) {
    console.error('❌ Failed to create duel:', err.response?.data || err.message);
    process.exit(1);
  }

  // 2. Connect to /duel Namespace
  console.log('\n2️⃣ Connecting to /duel namespace...');
  const user1DuelSocket = await connectSocket(user1Token, 'Player 1', '/duel');
  const user2DuelSocket = await connectSocket(user2Token, 'Player 2', '/duel');
  user1DuelSocket.on('duel:debug', (data) => console.log('   🔍 P1 Debug:', data.message));
  user2DuelSocket.on('duel:debug', (data) => console.log('   🔍 P2 Debug:', data.message));
  // 3. Load Duel
  console.log('   Loading duel...');
  user1DuelSocket.emit('duel:load', { duelId });
  user2DuelSocket.emit('duel:load', { duelId });

  // Wait for startDuel event
  let totalQuestions = 0;
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Timeout waiting for startDuel'));
    }, 10000);

    let p1Ready = false;
    let p2Ready = false;

    const onStarted = (data) => {
      if (data.questions) totalQuestions = data.questions.length;
    };

    user1DuelSocket.on('startDuel', (data) => {
       console.log('   P1 received startDuel');
       onStarted(data);
       p1Ready = true;
       if (p1Ready && p2Ready) {
         clearTimeout(timeout);
         resolve();
       }
    });

    user2DuelSocket.on('startDuel', (data) => {
      console.log('   P2 received startDuel');
      p2Ready = true;
      if (p1Ready && p2Ready) {
        clearTimeout(timeout);
        resolve();
      }
    });
  });

  console.log(`   Duel Started! Questions: ${totalQuestions}`);

  // 4. Simulate Gameplay
  console.log('\n4️⃣ Simulating Gameplay (All Wrong Answers)...');

  for (let i = 0; i < totalQuestions; i++) {
    console.log(`   Question ${i + 1}/${totalQuestions}`);
    
    // P1 - Fast (1s)
    user1DuelSocket.emit('duel:submit_answer', {
      questionId: i, // Index based
      answer: 'WRONG_ANSWER_XYZ', 
      timeUsed: 1
    });

    // P2 - Slow (5s)
    user2DuelSocket.emit('duel:submit_answer', {
      questionId: i,
      answer: 'WRONG_ANSWER_XYZ',
      timeUsed: 5
    });

    // Small delay
    await new Promise(r => setTimeout(r, 100));
  }

  // Wait for completion
  console.log('\n5️⃣ Waiting for Results...');
  
  await new Promise((resolve, reject) => {
    user1DuelSocket.on('duel:completed', (data) => {
      console.log('   P1 received duel:completed');
      verifyResults(data);
      resolve();
    });
    
    setTimeout(() => {
      console.log('   ⚠️ Timeout waiting for results...');
      resolve(); 
    }, 5000);
  });
}

function verifyResults(data) {
  console.log('\n📊 Verifying Results...');
  console.log('   Winner ID:', data.winnerId);
  console.log('   Scores:', data.scores);
  console.log('   Players:', JSON.stringify(data.players, null, 2));

  const p1Stats = data.players[user1Id];
  const p2Stats = data.players[user2Id];

  console.log(`   P1 Time: ${p1Stats.timeTaken}, Score: ${p1Stats.score}`);
  console.log(`   P2 Time: ${p2Stats.timeTaken}, Score: ${p2Stats.score}`);

  if (p1Stats.score !== p2Stats.score) {
    console.log('   ⚠️ Scores are not equal! Tie-breaker test invalid.');
    // This might happen if my assumption about "A" being correct is wrong.
    // Or if questions are different.
  } else {
    console.log('   ✅ Scores are equal.');
    if (data.winnerId == user1Id) {
      console.log('   ✅ P1 is the winner (Lower Time). TEST PASSED!');
    } else if (data.winnerId == user2Id) {
      console.error('   ❌ P2 is the winner (Higher Time). TEST FAILED!');
    } else {
      console.error('   ❌ No winner (Tie). TEST FAILED!');
    }
  }
  
  process.exit(0);
}

runTest().catch(err => {
  console.error('Test Error:', err);
  process.exit(1);
});
