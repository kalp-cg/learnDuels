const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const getRandomItem = (arr) => arr[Math.floor(Math.random() * arr.length)];
const getRandomInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

async function main() {
  console.log('🌱 Starting APPEND database seed (Adding dummy data)...');

  // 1. Fetch existing context
  const users = await prisma.user.findMany();
  if (users.length === 0) {
    console.error('❌ No users found. Please run seed-full.js first.');
    return;
  }
  console.log(`ℹ️ Found ${users.length} existing users.`);

  let topics = await prisma.topic.findMany();
  if (topics.length === 0) {
    console.log('⚠️ No topics found. Creating basic topics...');
    const topicData = [
      { name: 'JavaScript', slug: 'javascript', description: 'Web development language' },
      { name: 'Python', slug: 'python', description: 'Data science and backend' },
      { name: 'React', slug: 'react', description: 'UI Library' },
      { name: 'Node.js', slug: 'nodejs', description: 'JS Runtime' },
      { name: 'Flutter', slug: 'flutter', description: 'Cross-platform UI' },
      { name: 'SQL', slug: 'sql', description: 'Database querying' },
      { name: 'Algorithms', slug: 'algorithms', description: 'CS Fundamentals' },
      { name: 'System Design', slug: 'system-design', description: 'Architecture' },
    ];
    for (const t of topicData) {
      await prisma.topic.create({ data: t });
    }
    topics = await prisma.topic.findMany();
  }
  console.log(`ℹ️ Found ${topics.length} topics.`);

  // 2. Create ~300 Questions
  console.log('❓ Generating ~300 Questions...');
  const difficulties = ['easy', 'medium', 'hard'];
  const questionTypes = ['mcq', 'true_false']; // simplified
  
  const questionsData = [];
  for (let i = 0; i < 300; i++) {
    const topic = getRandomItem(topics);
    const author = getRandomItem(users);
    const type = Math.random() > 0.8 ? 'true_false' : 'mcq';
    
    let content, options, correctAnswer;

    if (type === 'mcq') {
      content = `What is a key feature of ${topic.name} (Question #${i + 1})?`;
      options = [
        { id: "A", text: "It is very fast" },
        { id: "B", text: "It is slow" },
        { id: "C", text: "It is outdated" },
        { id: "D", text: "None of the above" }
      ];
      correctAnswer = "A";
    } else {
      content = `${topic.name} is a programming language. (Question #${i + 1})`;
      options = [
        { id: "true", text: "True" },
        { id: "false", text: "False" }
      ];
      correctAnswer = "true";
    }

    questionsData.push({
      authorId: author.id,
      content: content,
      options: options,
      correctAnswer: correctAnswer,
      explanation: `This is a dummy explanation for question #${i + 1}.`,
      difficulty: getRandomItem(difficulties),
      type: type,
      status: 'published',
      timeLimit: getRandomInt(15, 60),
    });
  }

  // Batch create questions (Prisma createMany is efficient)
  await prisma.question.createMany({ data: questionsData });
  
  // We need to link them to topics. createMany doesn't return IDs easily in all DBs, 
  // so let's fetch the newly created questions or just link a bunch of random ones.
  // For simplicity in this "append" script, let's fetch all questions and ensure they have topics.
  const allQuestions = await prisma.question.findMany({
    where: { topics: { none: {} } }, // Find questions without topics
    take: 300
  });

  console.log(`🔗 Linking ${allQuestions.length} questions to topics...`);
  for (const q of allQuestions) {
    const topic = getRandomItem(topics);
    await prisma.questionTopic.create({
      data: {
        questionId: q.id,
        topicId: topic.id
      }
    });
  }

  // 3. Create ~30 Question Sets (Quizzes)
  console.log('📝 Creating ~30 Question Sets...');
  for (let i = 0; i < 30; i++) {
    const author = getRandomItem(users);
    const qs = await prisma.questionSet.create({
      data: {
        name: `Practice Quiz #${i + 1} - ${getRandomItem(topics).name}`,
        description: 'A randomly generated practice set.',
        authorId: author.id,
        visibility: 'public',
      }
    });

    // Add 5-10 random questions to this set
    const numQuestions = getRandomInt(5, 10);
    const randomQuestions = [];
    for(let j=0; j<numQuestions; j++) {
        randomQuestions.push(getRandomItem(allQuestions));
    }
    
    // Deduplicate
    const uniqueQuestions = [...new Set(randomQuestions)];

    for (let j = 0; j < uniqueQuestions.length; j++) {
      await prisma.questionSetItem.create({
        data: {
          questionSetId: qs.id,
          questionId: uniqueQuestions[j].id,
          orderIndex: j
        }
      });
    }
  }

  // 4. Create ~30 Leaderboard Entries
  console.log('🏆 Creating ~30 Leaderboard Entries...');
  for (let i = 0; i < 30; i++) {
    const user = getRandomItem(users);
    const topic = Math.random() > 0.3 ? getRandomItem(topics) : null; // 30% global
    const period = getRandomItem(['daily', 'weekly', 'monthly', 'all-time']);

    // Check if exists to avoid unique constraint error
    // Use findFirst because findUnique composite key with null might be tricky in some Prisma versions
    const exists = await prisma.leaderboardEntry.findFirst({
      where: {
        userId: user.id,
        topicId: topic ? topic.id : null,
        period: period
      }
    });

    if (!exists) {
        // For the unique constraint, we need to pass the exact value.
        // However, Prisma client usage for composite unique with nullable fields can be tricky.
        // Let's just try create and catch error, or use upsert.
        try {
            await prisma.leaderboardEntry.create({
                data: {
                    userId: user.id,
                    topicId: topic ? topic.id : null,
                    period: period,
                    rating: getRandomInt(1000, 2500),
                    points: getRandomInt(0, 5000),
                    wins: getRandomInt(0, 50),
                    totalDuels: getRandomInt(50, 100)
                }
            });
        } catch (e) {
            // Ignore unique constraint violations
        }
    }
  }

  // 5. Create ~30 Challenges
  console.log('⚔️ Creating ~30 Challenges...');
  for (let i = 0; i < 30; i++) {
    const challenger = getRandomItem(users);
    const opponent = getRandomItem(users.filter(u => u.id !== challenger.id));
    
    const challenge = await prisma.challenge.create({
      data: {
        challengerId: challenger.id,
        type: 'instant',
        status: getRandomItem(['pending', 'active', 'completed']),
        settings: {
            difficulty: 'medium',
            numQuestions: 5,
            topicIds: [getRandomItem(topics).id]
        }
      }
    });

    await prisma.challengeParticipant.create({
      data: {
        challengeId: challenge.id,
        userId: challenger.id,
        status: 'accepted',
        score: getRandomInt(0, 50)
      }
    });

    await prisma.challengeParticipant.create({
      data: {
        challengeId: challenge.id,
        userId: opponent.id,
        status: getRandomItem(['invited', 'accepted', 'declined']),
        score: getRandomInt(0, 50)
      }
    });
  }

  // 6. Create ~30 Activities
  console.log('activity Creating ~30 Activities...');
  const activityTypes = ['create_quiz', 'won_duel', 'new_highscore', 'level_up'];
  for (let i = 0; i < 30; i++) {
    const user = getRandomItem(users);
    await prisma.activity.create({
      data: {
        userId: user.id,
        type: getRandomItem(activityTypes),
        data: { message: 'Dummy activity data' }
      }
    });
  }

  // 7. Create ~30 Notifications
  console.log('🔔 Creating ~30 Notifications...');
  const notifTypes = ['challenge_received', 'duel_invite', 'follow'];
  for (let i = 0; i < 30; i++) {
    const user = getRandomItem(users);
    await prisma.notification.create({
      data: {
        userId: user.id,
        type: getRandomItem(notifTypes),
        message: 'You have a new notification!',
        isRead: Math.random() > 0.5
      }
    });
  }

  console.log('🎉 Append seed completed successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
