const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting seed...');

  // Clear existing data
  console.log('🗑️  Clearing existing data...');
  
  // Delete in correct order to handle foreign keys
  await prisma.notification.deleteMany();
  await prisma.flag.deleteMany();
  await prisma.report.deleteMany();
  await prisma.duelAnswer.deleteMany();
  await prisma.duelQuestion.deleteMany();
  await prisma.duel.deleteMany();
  await prisma.challengeParticipant.deleteMany();
  await prisma.challenge.deleteMany();
  await prisma.attempt.deleteMany();
  await prisma.leaderboardEntry.deleteMany();
  await prisma.questionSetItem.deleteMany();
  await prisma.questionSet.deleteMany();
  await prisma.questionTopic.deleteMany();
  await prisma.question.deleteMany();
  await prisma.topic.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.userFollower.deleteMany();
  await prisma.user.deleteMany();
  
  console.log('✅ Database cleared successfully');

  // Create Users
  console.log('👥 Creating users...');
  const hashedPassword = await bcrypt.hash('password123', 10);

  const admin = await prisma.user.create({
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
  });

  const users = [];
  for (let i = 1; i <= 20; i++) {
    const user = await prisma.user.create({
      data: {
        username: `user${i}`,
        email: `user${i}@test.com`,
        passwordHash: hashedPassword,
        bio: `I'm test user number ${i}`,
        xp: Math.floor(Math.random() * 5000),
        level: Math.floor(Math.random() * 10) + 1,
        reputation: Math.floor(Math.random() * 50),
      },
    });
    users.push(user);
  }

  console.log(`✅ Created ${users.length + 1} users`);

  // Create Topics (hierarchical)
  console.log('📚 Creating topics...');
  
  const programming = await prisma.topic.create({
    data: { name: 'Programming', slug: 'programming' },
  });

  const javascript = await prisma.topic.create({
    data: { name: 'JavaScript', slug: 'javascript', parentId: programming.id },
  });

  const python = await prisma.topic.create({
    data: { name: 'Python', slug: 'python', parentId: programming.id },
  });

  const mathematics = await prisma.topic.create({
    data: { name: 'Mathematics', slug: 'mathematics' },
  });

  const algebra = await prisma.topic.create({
    data: { name: 'Algebra', slug: 'algebra', parentId: mathematics.id },
  });

  const science = await prisma.topic.create({
    data: { name: 'Science', slug: 'science' },
  });

  const physics = await prisma.topic.create({
    data: { name: 'Physics', slug: 'physics', parentId: science.id },
  });

  const topics = [javascript, python, algebra, physics];
  console.log('✅ Created topics');

  // Create Questions
  console.log('❓ Creating questions...');
  
  const questions = [];
  const difficulties = ['easy', 'medium', 'hard'];
  
  for (let i = 0; i < 50; i++) {
    const topic = topics[i % topics.length];
    const question = await prisma.question.create({
      data: {
        authorId: users[i % users.length].id,
        difficulty: difficulties[i % 3],
        type: 'mcq',
        content: `Sample question ${i + 1}. What is the answer?`,
        options: [
          { id: 'A', text: 'Option A' },
          { id: 'B', text: 'Option B' },
          { id: 'C', text: 'Option C' },
          { id: 'D', text: 'Option D' },
        ],
        correctAnswer: 'A',
        explanation: 'The correct answer is A because...',
        timeLimit: 30,
        status: 'published',
        topics: {
          create: [{ topicId: topic.id }]
        }
      },
    });
    questions.push(question);
  }

  console.log(`✅ Created ${questions.length} questions`);

  // Create Question Sets
  console.log('📝 Creating question sets...');
  
  const questionSets = [];
  for (let i = 0; i < 10; i++) {
    const selectedQuestions = questions.slice(i * 5, (i * 5) + 5);
    const questionSet = await prisma.questionSet.create({
      data: {
        name: `Quiz Set ${i + 1}`,
        description: `A collection of ${selectedQuestions.length} questions`,
        authorId: users[i % users.length].id,
        visibility: i % 2 === 0 ? 'public' : 'private',
        items: {
          create: selectedQuestions.map((q, index) => ({
            questionId: q.id,
            orderIndex: index
          }))
        }
      },
    });
    questionSets.push(questionSet);
  }

  console.log(`✅ Created ${questionSets.length} question sets`);

  // Create Follows
  console.log('👥 Creating follow relationships...');
  
  let followCount = 0;
  for (let i = 0; i < users.length; i++) {
    for (let j = 0; j < 3; j++) {
      const followingIndex = (i + j + 1) % users.length;
      if (i !== followingIndex) {
        await prisma.userFollower.create({
          data: {
            followerId: users[i].id,
            followingId: users[followingIndex].id,
          },
        });
        
        // Update counts
        await prisma.user.update({
          where: { id: users[i].id },
          data: { followingCount: { increment: 1 } },
        });
        await prisma.user.update({
          where: { id: users[followingIndex].id },
          data: { followersCount: { increment: 1 } },
        });
        
        followCount++;
      }
    }
  }

  console.log(`✅ Created ${followCount} follow relationships`);

  // Create Attempts
  console.log('📊 Creating attempts...');
  
  for (let i = 0; i < 30; i++) {
    await prisma.attempt.create({
      data: {
        userId: users[i % users.length].id,
        questionSetId: questionSets[i % questionSets.length].id,
        answers: [
          { questionId: 1, selectedAnswer: 'A', isCorrect: true, timeTaken: 25 },
          { questionId: 2, selectedAnswer: 'B', isCorrect: false, timeTaken: 30 },
          { questionId: 3, selectedAnswer: 'A', isCorrect: true, timeTaken: 20 },
        ],
        score: 2,
        timeTaken: 75,
      },
    });
  }

  console.log('✅ Created attempts');

  // Create Notifications
  console.log('🔔 Creating notifications...');
  
  for (let i = 0; i < 20; i++) {
    await prisma.notification.create({
      data: {
        userId: users[i % users.length].id,
        message: `Notification ${i + 1}: You have a new challenge!`,
        type: 'challenge_received',
        data: { challengeId: i + 1 },
        isRead: i % 3 === 0,
      },
    });
  }

  console.log('✅ Created notifications');

  console.log('🎉 Seed completed successfully!');
  
  console.log('\n📊 Summary:');
  console.log(`- Users: ${users.length + 1} (including 1 admin)`);
  console.log(`- Topics: 7 topics created`);
  console.log(`- Questions: ${questions.length}`);
  console.log(`- Question Sets: ${questionSets.length}`);
  console.log(`- Follow relationships: ${followCount}`);
  console.log(`- Attempts: 30`);
  console.log(`- Notifications: 20`);
  console.log('\n✅ You can now start the backend server!');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
