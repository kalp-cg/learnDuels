const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting FULL database seed...');

  // 1. Clear existing data
  console.log('🧹 Clearing existing data...');
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
  await prisma.message.deleteMany();
  await prisma.conversationParticipant.deleteMany();
  await prisma.conversation.deleteMany();
  await prisma.user.deleteMany();

  // 2. Create Users
  console.log('👥 Creating users...');
  const passwordHash = await bcrypt.hash('User0000', 10);
  
  const specificUsers = [
    { fullName: 'Ashwani kumar', email: 'ashwani@gmail.com', rating: 2450 },
    { fullName: 'Akshar gangani', email: 'akshar@gmail.com', rating: 2380 },
    { fullName: 'Narvin', email: 'narvin@gmail.com', rating: 2310 },
    { fullName: 'Dhruv sonagram', email: 'dhruv@gmail.com', rating: 2245 },
    { fullName: 'Arya patel', email: 'arya@gmail.com', rating: 2180 },
    { fullName: 'Veer modi', email: 'veer@gmail.com', rating: 2120 },
    { fullName: 'Krish shyra', email: 'krish@gmail.com', rating: 2055 },
    { fullName: 'Nagesh jagtap', email: 'nagesh@gmail.com', rating: 1990 },
    { fullName: 'Khushi Rajput', email: 'khushi@gmail.com', rating: 1925 },
    { fullName: 'Krishna Paridwal', email: 'krishna@gmail.com', rating: 1860 },
    { fullName: 'Drishti Gupta', email: 'drishti@gmail.com', rating: 1795 },
    { fullName: 'Dev patel', email: 'dev@gmail.com', rating: 1730 },
    { fullName: 'Jeevan Kadam', email: 'jeevan@gmail.com', rating: 1665 },
    { fullName: 'Kashyap Dhamecha', email: 'kashyap@gmail.com', rating: 1600 },
    { fullName: 'Het Barsana', email: 'het@gmail.com', rating: 1535 },
    { fullName: 'Nehil ghetiya', email: 'nehil@gmail.com', rating: 1470 },
    { fullName: 'Pavan Patel', email: 'pavan@gmail.com', rating: 1405 },
    { fullName: 'Prathmesh pimple', email: 'prathmesh@gmail.com', rating: 1340 },
    { fullName: 'mohil Mundke', email: 'mohil@gmail.com', rating: 1275 },
    { fullName: 'Vanshika Zawar', email: 'vanshika@gmail.com', rating: 1210 },
    // Adding more to reach ~37
    { fullName: 'Rohan Sharma', email: 'rohan@gmail.com', rating: 1200 },
    { fullName: 'Priya Singh', email: 'priya@gmail.com', rating: 1190 },
    { fullName: 'Amit Verma', email: 'amit@gmail.com', rating: 1180 },
    { fullName: 'Sneha Gupta', email: 'sneha@gmail.com', rating: 1170 },
    { fullName: 'Rahul Kumar', email: 'rahul@gmail.com', rating: 1160 },
    { fullName: 'Anjali Mishra', email: 'anjali@gmail.com', rating: 1150 },
    { fullName: 'Vikram Singh', email: 'vikram@gmail.com', rating: 1140 },
    { fullName: 'Pooja Yadav', email: 'pooja@gmail.com', rating: 1130 },
    { fullName: 'Suresh Raina', email: 'suresh@gmail.com', rating: 1120 },
    { fullName: 'Kavita Das', email: 'kavita@gmail.com', rating: 1110 },
    { fullName: 'Arjun Reddy', email: 'arjun@gmail.com', rating: 1100 },
    { fullName: 'Meera Nair', email: 'meera@gmail.com', rating: 1090 },
    { fullName: 'Rajesh Koothrappali', email: 'rajesh@gmail.com', rating: 1080 },
    { fullName: 'Penny Hofstadter', email: 'penny@gmail.com', rating: 1070 },
    { fullName: 'Sheldon Cooper', email: 'sheldon@gmail.com', rating: 1060 },
    { fullName: 'Leonard Hofstadter', email: 'leonard@gmail.com', rating: 1050 },
    { fullName: 'Howard Wolowitz', email: 'howard@gmail.com', rating: 1040 },
  ];

  const createdUsers = [];
  for (const u of specificUsers) {
    const username = u.email.split('@')[0];
    const user = await prisma.user.create({
      data: {
        username: username,
        email: u.email,
        fullName: u.fullName,
        passwordHash: passwordHash,
        role: 'user',
        rating: u.rating,
        xp: Math.floor(u.rating * 10),
        level: Math.floor(u.rating / 100),
        isActive: true,
      }
    });
    createdUsers.push(user);
  }
  console.log(`✅ Created ${createdUsers.length} users`);

  // 3. Create Topics
  console.log('📚 Creating topics...');
  const topics = await Promise.all([
    prisma.topic.create({ data: { name: 'Mathematics', slug: 'mathematics' } }),
    prisma.topic.create({ data: { name: 'Science', slug: 'science' } }),
    prisma.topic.create({ data: { name: 'Programming', slug: 'programming' } }),
    prisma.topic.create({ data: { name: 'History', slug: 'history' } }),
    prisma.topic.create({ data: { name: 'Geography', slug: 'geography' } }),
  ]);
  
  const subTopics = await Promise.all([
    prisma.topic.create({ data: { name: 'Algebra', slug: 'algebra', parentId: topics[0].id } }),
    prisma.topic.create({ data: { name: 'Physics', slug: 'physics', parentId: topics[1].id } }),
    prisma.topic.create({ data: { name: 'JavaScript', slug: 'javascript', parentId: topics[2].id } }),
  ]);

  console.log(`✅ Created ${topics.length + subTopics.length} topics`);

  // 4. Create Questions
  console.log('❓ Creating questions...');
  const authorId = createdUsers[0].id; // Ashwani is the author

  const questionsData = [
    // Math
    { content: 'What is 2 + 2?', options: ['3', '4', '5', '6'], correct: '4', topic: subTopics[0].id },
    { content: 'Solve: 3x = 12', options: ['2', '3', '4', '5'], correct: '4', topic: subTopics[0].id },
    { content: 'Square root of 64?', options: ['6', '7', '8', '9'], correct: '8', topic: subTopics[0].id },
    // Science
    { content: 'Speed of light?', options: ['300k km/s', '150k km/s', '100k km/s', '500k km/s'], correct: '300k km/s', topic: subTopics[1].id },
    { content: 'Force = Mass x ?', options: ['Velocity', 'Acceleration', 'Time', 'Distance'], correct: 'Acceleration', topic: subTopics[1].id },
    // Programming
    { content: 'What is a variable?', options: ['A container', 'A function', 'A loop', 'A class'], correct: 'A container', topic: subTopics[2].id },
    { content: 'JS keyword for constant?', options: ['var', 'let', 'const', 'final'], correct: 'const', topic: subTopics[2].id },
    { content: 'Array index starts at?', options: ['0', '1', '-1', '10'], correct: '0', topic: subTopics[2].id },
  ];

  for (const q of questionsData) {
    await prisma.question.create({
      data: {
        authorId: authorId,
        content: q.content,
        options: q.options,
        correctAnswer: q.correct,
        difficulty: 'medium',
        status: 'published',
        topics: {
          create: { topicId: q.topic }
        }
      }
    });
  }
  console.log(`✅ Created ${questionsData.length} questions`);

  console.log('🎉 Seed completed successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
