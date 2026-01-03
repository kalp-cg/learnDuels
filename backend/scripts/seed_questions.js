const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const fileMap = {
  'operating_systems.js': { name: 'Operating Systems', slug: 'operating-systems' },
  'cpp.js': { name: 'C++', slug: 'cpp' },
  'dsa_array.js': { name: 'DSA - Arrays', slug: 'dsa-arrays' },
  'dsa_string.js': { name: 'DSA - Strings', slug: 'dsa-strings' },
  'express.js': { name: 'Express.js', slug: 'express-js' },
  'javascript.js': { name: 'JavaScript', slug: 'javascript' },
  'next.js': { name: 'Next.js', slug: 'next-js' },
  'node.js': { name: 'Node.js', slug: 'node-js' },
  'python.js': { name: 'Python', slug: 'python' },
  'react.js': { name: 'React', slug: 'react' }
};

async function main() {
  console.log('🚀 Starting full question seed...');

  try {
    // 1. Find an author
    const author = await prisma.user.findFirst({
      where: { role: 'admin' },
    }) || await prisma.user.findFirst();

    if (!author) {
      throw new Error('No user found to assign as author. Please seed users first.');
    }
    console.log(`👤 Using author: ${author.username} (ID: ${author.id})`);

    // 2. Clear existing questions
    console.log('🗑️  Clearing existing questions...');
    await prisma.savedQuestion.deleteMany();
    await prisma.questionTopic.deleteMany();
    await prisma.questionSetItem.deleteMany();
    await prisma.duelQuestion.deleteMany();
    await prisma.duelAnswer.deleteMany();
    await prisma.flag.deleteMany();
    const deletedQuestions = await prisma.question.deleteMany();
    console.log(`✅ Deleted ${deletedQuestions.count} existing questions.`);

    // 3. Iterate over files and seed
    let totalSeeded = 0;

    for (const [filename, topicInfo] of Object.entries(fileMap)) {
      console.log(`\n📂 Processing ${filename} for topic "${topicInfo.name}"...`);
      
      try {
        const questions = require(`../../questions_scrapping/${filename}`);
        
        // Ensure topic exists
        let topic = await prisma.topic.findUnique({
            where: { slug: topicInfo.slug }
        });

        if (!topic) {
            console.log(`✨ Creating topic "${topicInfo.name}" (slug: ${topicInfo.slug})...`);
            topic = await prisma.topic.create({
                data: {
                    name: topicInfo.name,
                    slug: topicInfo.slug,
                    description: `Questions about ${topicInfo.name}`,
                }
            });
        }
        
        let count = 0;
        for (const q of questions) {
            if (!q.question || !q.options || !q.answer) {
                continue;
            }
             await prisma.question.create({
                data: {
                    content: q.question,
                    options: q.options,
                    correctAnswer: q.answer,
                    explanation: q.explanation || null,
                    difficulty: 'medium',
                    type: 'mcq',
                    status: 'published',
                    authorId: author.id,
                    topics: {
                        create: {
                            topicId: topic.id,
                        }
                    }
                }
            });
            count++;
        }
        console.log(`✅ Seeded ${count} questions for ${topicInfo.name}`);
        totalSeeded += count;

      } catch (err) {
        console.error(`❌ Failed to seed ${filename}:`, err.message);
      }
    }

    console.log(`\n🎉 Total questions seeded: ${totalSeeded}`);

  } catch (error) {
    console.error('❌ Error seeding questions:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();
