const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting seed...');

  // Clear existing data
  console.log('Clearing existing data...');
  await prisma.flag.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.duelAnswer.deleteMany();
  await prisma.duelQuestion.deleteMany();
  await prisma.duel.deleteMany();
  await prisma.attempt.deleteMany();
  await prisma.challengeParticipant.deleteMany();
  await prisma.challenge.deleteMany();
  await prisma.questionSetItem.deleteMany();
  await prisma.questionSet.deleteMany();
  await prisma.questionTopic.deleteMany();
  await prisma.question.deleteMany();
  await prisma.leaderboardEntry.deleteMany();
  await prisma.userFollower.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.report.deleteMany();
  await prisma.topic.deleteMany();
  await prisma.user.deleteMany();

  // Create Users
  console.log('Creating users...');
  const hashedPassword = await bcrypt.hash('password123', 10);
  
  const users = await Promise.all([
    prisma.user.create({
      data: {
        username: 'admin',
        email: 'admin@learnduels.com',
        passwordHash: hashedPassword,
        bio: 'Platform administrator',
        role: 'admin',
        xp: 10000,
        level: 10,
        reputation: 100,
      },
    }),
    prisma.user.create({
      data: {
        username: 'alice_wonder',
        email: 'alice@example.com',
        passwordHash: hashedPassword,
        bio: 'Love learning new things!',
        xp: 5000,
        level: 5,
        reputation: 50,
      },
    }),
    prisma.user.create({
      data: {
        username: 'bob_builder',
        email: 'bob@example.com',
        passwordHash: hashedPassword,
        bio: 'Building knowledge brick by brick',
        xp: 3000,
        level: 3,
        reputation: 30,
      },
    }),
    prisma.user.create({
      data: {
        username: 'charlie_chan',
        email: 'charlie@example.com',
        passwordHash: hashedPassword,
        bio: 'Quiz master!',
        xp: 7000,
        level: 7,
        reputation: 70,
      },
    }),
    prisma.user.create({
      data: {
        username: 'diana_prince',
        email: 'diana@example.com',
        passwordHash: hashedPassword,
        bio: 'Learning warrior',
        xp: 4000,
        level: 4,
        reputation: 40,
      },
    }),
  ]);

  console.log(`✅ Created ${users.length} users`);

  // Create Topics
  console.log('Creating topics...');
  
  const mathTopic = await prisma.topic.create({ data: { name: 'Mathematics', slug: 'mathematics' } });
  const algebraTopic = await prisma.topic.create({ data: { name: 'Algebra', slug: 'algebra', parentId: mathTopic.id } });
  const geometryTopic = await prisma.topic.create({ data: { name: 'Geometry', slug: 'geometry', parentId: mathTopic.id } });
  const scienceTopic = await prisma.topic.create({ data: { name: 'Science', slug: 'science' } });
  const physicsTopic = await prisma.topic.create({ data: { name: 'Physics', slug: 'physics', parentId: scienceTopic.id } });
  const chemistryTopic = await prisma.topic.create({ data: { name: 'Chemistry', slug: 'chemistry', parentId: scienceTopic.id } });
  const programmingTopic = await prisma.topic.create({ data: { name: 'Programming', slug: 'programming' } });
  const javaScriptTopic = await prisma.topic.create({ data: { name: 'JavaScript', slug: 'javascript', parentId: programmingTopic.id } });
  const historyTopic = await prisma.topic.create({ data: { name: 'History', slug: 'history' } });

  console.log('✅ Created 9 topics');

  // Create Questions
  console.log('Creating questions...');
  
  const questions = await Promise.all([
    prisma.question.create({
      data: {
        authorId: users[1].id,
        difficulty: 'easy',
        content: 'What is 2 + 2?',
        options: ['3', '4', '5', '6'],
        correctAnswer: '4',
        explanation: '2 + 2 equals 4',
        status: 'published',
        topics: {
          create: { topicId: algebraTopic.id }
        }
      },
    }),
    prisma.question.create({
      data: {
        authorId: users[1].id,
        difficulty: 'medium',
        content: 'Solve: 2x + 5 = 15',
        options: ['5', '10', '7', '3'],
        correctAnswer: '5',
        explanation: 'x = 5',
        timeLimit: 60,
        status: 'published',
        topics: {
          create: { topicId: algebraTopic.id }
        }
      },
    }),
    prisma.question.create({
      data: {
        authorId: users[3].id,
        difficulty: 'easy',
        content: 'Sum of angles in triangle?',
        options: ['90°', '180°', '270°', '360°'],
        correctAnswer: '180°',
        explanation: 'Always 180 degrees',
        status: 'published',
        topics: {
          create: { topicId: geometryTopic.id }
        }
      },
    }),
    prisma.question.create({
      data: {
        authorId: users[2].id,
        difficulty: 'medium',
        content: 'Speed of light?',
        options: ['300,000 km/s', '150,000 km/s', '450,000 km/s', '200,000 km/s'],
        correctAnswer: '300k km/s',
        explanation: '~300,000 km/s',
        timeLimit: 45,
        status: 'published',
        topics: {
          create: { topicId: physicsTopic.id }
        }
      },
    }),
    prisma.question.create({
      data: {
        authorId: users[2].id,
        difficulty: 'easy',
        content: 'Chemical symbol for water?',
        options: ['H2O', 'CO2', 'O2', 'H2'],
        correctAnswer: 'H2O',
        explanation: 'H2O = water',
        status: 'published',
        topics: {
          create: { topicId: chemistryTopic.id }
        }
      },
    }),
    prisma.question.create({
      data: {
        authorId: users[3].id,
        difficulty: 'medium',
        content: 'Declare constant in JS?',
        options: ['var', 'let', 'const', 'constant'],
        correctAnswer: 'const',
        explanation: 'Use const keyword',
        timeLimit: 45,
        status: 'published',
        topics: {
          create: { topicId: javaScriptTopic.id }
        }
      },
    }),
  ]);

  console.log(`✅ Created ${questions.length} questions`);

  // Create Question Sets
  const questionSets = await Promise.all([
    prisma.questionSet.create({
      data: {
        name: 'Basic Math Quiz',
        authorId: users[1].id,
        questionIds: [questions[0].id, questions[1].id, questions[2].id],
        visibility: 'public',
      },
    }),
    prisma.questionSet.create({
      data: {
        name: 'Science Fundamentals',
        authorId: users[2].id,
        questionIds: [questions[3].id, questions[4].id],
        visibility: 'public',
      },
    }),
  ]);

  console.log(`✅ Created ${questionSets.length} question sets`);

  console.log('✅ Seed completed!');
  console.log('\n🔑 Login: alice@example.com / password123');
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
