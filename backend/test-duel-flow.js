const io = require('socket.io-client');
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const API_URL = 'http://localhost:4000/api';
const SOCKET_URL = 'http://localhost:4000';

// Test Users
const ARYA_CREDENTIALS = { email: 'arya@example.com', password: 'password123' };
const DEV_CREDENTIALS = { email: 'dev@example.com', password: 'password123' };

let aryaToken, devToken;
let aryaId, devId;
let aryaSocket, devSocket;
let challengeId;
let testTopicId;

async function setupData() {
  console.log('🛠️ Setting up test data...');
  
  const author = await prisma.user.findFirst();
  if (!author) {
    console.error('❌ No users found in DB. Run ensure-test-users.js first.');
    process.exit(1);
  }

  // Create Topic
  const topic = await prisma.topic.upsert({
    where: { slug: 'test-topic' },
    update: {},
    create: { name: 'Test Topic', slug: 'test-topic', description: 'For testing' }
  });
  testTopicId = topic.id;
  console.log(`   Topic created: ${topic.name} (${topic.id})`);

  // Create Questions
  // Check if we already have enough questions
  const count = await prisma.question.count({
    where: { topics: { some: { topicId: topic.id } } }
  });

  if (count < 5) {
    const questions = [];
    for (let i = 1; i <= 5; i++) {
      const q = await prisma.question.create({
        data: {
          content: `Test Question ${i} - ${Date.now()}?`,
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          difficulty: 'easy',
          type: 'mcq',
          status: 'published',
          authorId: author.id,
          topics: {
            create: { topicId: topic.id }
          }
        }
      });
      questions.push(q);
    }
    console.log(`   Created ${questions.length} test questions`);
  } else {
    console.log(`   Topic has ${count} questions, skipping creation.`);
  }
}

async function login(credentials) {
  try {
    const res = await axios.post(`${API_URL}/auth/login`, credentials);
    return { token: res.data.data.accessToken, userId: res.data.data.user.id };
  } catch (error) {
    console.error(`Login failed for ${credentials.email}:`, error);
    process.exit(1);
  }
}

function connectSocket(token, name) {
  return new Promise((resolve, reject) => {
    const socket = io(SOCKET_URL, {
      auth: { token },
      transports: ['websocket'],
      forceNew: true,
    });

    socket.on('connect', () => {
      console.log(`✅ ${name} connected to socket (${socket.id})`);
      resolve(socket);
    });

    socket.on('connect_error', (err) => {
      console.error(`❌ ${name} socket connection error:`, err.message);
      reject(err);
    });
  });
}

async function runTest() {
  console.log('🚀 Starting End-to-End Duel Flow Test...');

  await setupData();

  // 1. Login
  console.log('\n🔑 Logging in...');
  const arya = await login(ARYA_CREDENTIALS);
  aryaToken = arya.token;
  aryaId = arya.userId;
  console.log(`Arya logged in (ID: ${aryaId})`);

  const dev = await login(DEV_CREDENTIALS);
  devToken = dev.token;
  devId = dev.userId;
  console.log(`Dev logged in (ID: ${devId})`);

  // 2. Connect Sockets
  console.log('\n🔌 Connecting sockets...');
  aryaSocket = await connectSocket(aryaToken, 'Arya');
  devSocket = await connectSocket(devToken, 'Dev');

  // 3. Setup Listeners
  devSocket.on('duel:invitation_received', (data) => {
    console.log('\n📩 Dev received invitation:', data);
    challengeId = data.challengeId;
    
    // Accept Challenge
    console.log(`👍 Dev accepting challenge ${challengeId}...`);
    devSocket.emit('challenge:accept', { challengeId });
  });

  const gameStartPromise = new Promise((resolve) => {
    let startedCount = 0;
    const onStarted = (data) => {
      console.log(`\n🎮 Game Started for ${data.players.find(p => p.id === aryaId) ? 'Arya' : 'Dev'}! Room: ${data.roomId}`);
      console.log(`   Questions: ${data.questions.length}`);
      startedCount++;
      if (startedCount === 2) resolve(data);
    };

    aryaSocket.on('challenge:started', onStarted);
    devSocket.on('challenge:started', onStarted);
  });

  // 4. Send Challenge (Arya -> Dev)
  console.log('\n⚔️ Arya sending challenge to Dev...');
  try {
    const res = await axios.post(
      `${API_URL}/duels`,
      {
        opponentId: devId,
        categoryId: testTopicId,
        difficultyId: 'easy', // Using string as per seed data, or check API expectation
        questionCount: 5
      },
      { headers: { Authorization: `Bearer ${aryaToken}` } }
    );
    console.log('✅ Challenge created via API:', res.data.data);
  } catch (error) {
    console.error('❌ Failed to create challenge:', error.response?.data || error.message);
  }

  // 5. Wait for Game Start
  const gameData = await gameStartPromise;
  const roomId = gameData.roomId;
  const questions = gameData.questions;

  // 6. Simulate Game Play
  console.log('\n🎲 Simulating Game Play...');
  
  // Answer Question 1
  const q1 = questions[0];
  console.log(`\n❓ Question 1: ${q1.questionText}`);
  
  // Arya answers correctly
  aryaSocket.emit('challenge:answer', {
    challengeId: gameData.challengeId,
    questionId: q1.id,
    selectedAnswer: q1.optionA, // Assuming first option is correct for test
    timeTaken: 5
  });
  console.log('Arya answered Q1');

  // Dev answers
  devSocket.emit('challenge:answer', {
    challengeId: gameData.challengeId,
    questionId: q1.id,
    selectedAnswer: q1.optionB,
    timeTaken: 8
  });
  console.log('Dev answered Q1');

  // Wait a bit
  await new Promise(r => setTimeout(r, 1000));

  console.log('\n✅ Test Completed Successfully!');
  process.exit(0);
}

runTest().catch(console.error);
