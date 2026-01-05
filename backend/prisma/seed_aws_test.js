const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting AWS Test Seed...');

  // 1. Create Users
  const password = 'pass0000';
  const hashedPassword = await bcrypt.hash(password, 10);

  const usersToCreate = [
    { username: 'kalp', email: 'kalp@learnduels.com' },
    { username: 'arya', email: 'arya@learnduels.com' },
    { username: 'dev', email: 'dev@learnduels.com' },
    { username: 'dax', email: 'dax@learnduels.com' },
    { username: 'jatin', email: 'jatin@learnduels.com' },
    { username: 'kalpan', email: 'kalpan@learnduels.com' },
  ];

  console.log('Creating users...');
  const createdUsers = [];
  for (const user of usersToCreate) {
    const upsertedUser = await prisma.user.upsert({
      where: { username: user.username },
      update: { passwordHash: hashedPassword },
      create: {
        username: user.username,
        email: user.email,
        passwordHash: hashedPassword,
        role: 'user',
        isActive: true,
      },
    });
    createdUsers.push(upsertedUser);
    console.log(`✅ User ${user.username} ready`);
  }

  const authorId = createdUsers[0].id; // Use 'kalp' as author for questions

  // 2. Create Topics
  console.log('Creating topics...');
  const topics = [
    { name: 'React', slug: 'react' },
    { name: 'Node.js', slug: 'node-js' },
    { name: 'Next.js', slug: 'next-js' },
  ];

  const createdTopics = {};
  for (const topic of topics) {
    const t = await prisma.topic.upsert({
      where: { slug: topic.slug },
      update: {},
      create: { name: topic.name, slug: topic.slug },
    });
    createdTopics[topic.slug] = t.id;
    console.log(`✅ Topic ${topic.name} ready`);
  }

  // 3. Create Questions
  console.log('Creating questions...');

  const questions = [
    // React Questions
    {
      content: 'What is the primary purpose of useEffect in React?',
      options: ['To handle side effects', 'To create components', 'To manage state', 'To style elements'],
      correctAnswer: 'To handle side effects',
      topicSlug: 'react',
    },
    {
      content: 'Which hook is used to manage state in a functional component?',
      options: ['useEffect', 'useState', 'useContext', 'useReducer'],
      correctAnswer: 'useState',
      topicSlug: 'react',
    },
    {
      content: 'What is the virtual DOM?',
      options: ['A direct copy of the real DOM', 'A lightweight representation of the real DOM', 'A browser extension', 'A database'],
      correctAnswer: 'A lightweight representation of the real DOM',
      topicSlug: 'react',
    },
    {
      content: 'How do you pass data from parent to child in React?',
      options: ['State', 'Props', 'Context', 'Redux'],
      correctAnswer: 'Props',
      topicSlug: 'react',
    },
    {
      content: 'What is JSX?',
      options: ['JavaScript XML', 'Java Syntax Extension', 'JSON Style XML', 'JavaScript XSLT'],
      correctAnswer: 'JavaScript XML',
      topicSlug: 'react',
    },

    // Node.js Questions
    {
      content: 'What is Node.js built on?',
      options: ['Python', 'V8 JavaScript Engine', 'Java Virtual Machine', 'SpiderMonkey'],
      correctAnswer: 'V8 JavaScript Engine',
      topicSlug: 'node-js',
    },
    {
      content: 'Which module is used for file operations in Node.js?',
      options: ['http', 'fs', 'path', 'os'],
      correctAnswer: 'fs',
      topicSlug: 'node-js',
    },
    {
      content: 'What is the default scope of a module in Node.js?',
      options: ['Global', 'Local to the module', 'Shared', 'Public'],
      correctAnswer: 'Local to the module',
      topicSlug: 'node-js',
    },
    {
      content: 'Which event is emitted when an unhandled exception occurs?',
      options: ['error', 'uncaughtException', 'fail', 'exception'],
      correctAnswer: 'uncaughtException',
      topicSlug: 'node-js',
    },
    {
      content: 'What does npm stand for?',
      options: ['Node Project Manager', 'Node Package Manager', 'New Package Manager', 'Node Process Manager'],
      correctAnswer: 'Node Package Manager',
      topicSlug: 'node-js',
    },

    // Next.js Questions
    {
      content: 'Which function is used for Static Site Generation (SSG) in Next.js (Pages Router)?',
      options: ['getServerSideProps', 'getStaticProps', 'getInitialProps', 'useEffect'],
      correctAnswer: 'getStaticProps',
      topicSlug: 'next-js',
    },
    {
      content: 'What is the file-based routing convention for a dynamic route in Next.js?',
      options: ['[id].js', '{id}.js', '(id).js', '<id>.js'],
      correctAnswer: '[id].js',
      topicSlug: 'next-js',
    },
    {
      content: 'Which component is used to optimize images in Next.js?',
      options: ['<img>', '<Image />', '<Picture />', '<OptimizedImage />'],
      correctAnswer: '<Image />',
      topicSlug: 'next-js',
    },
    {
      content: 'What is the purpose of the "pages/api" directory in Next.js?',
      options: ['To store static assets', 'To define API routes', 'To store components', 'To configure the database'],
      correctAnswer: 'To define API routes',
      topicSlug: 'next-js',
    },
    {
      content: 'Which rendering method is best for SEO-heavy pages that change frequently?',
      options: ['Client Side Rendering', 'Static Site Generation', 'Server Side Rendering', 'Incremental Static Regeneration'],
      correctAnswer: 'Server Side Rendering',
      topicSlug: 'next-js',
    },
  ];

  for (const q of questions) {
    // Check if question exists to avoid duplicates
    const existing = await prisma.question.findFirst({
      where: { content: q.content },
    });

    if (!existing) {
      const createdQ = await prisma.question.create({
        data: {
          content: q.content,
          options: q.options,
          correctAnswer: q.correctAnswer,
          difficulty: 'medium',
          type: 'mcq',
          status: 'published',
          authorId: authorId,
          topics: {
            create: {
              topicId: createdTopics[q.topicSlug],
            },
          },
        },
      });
      console.log(`✅ Created question: ${q.content.substring(0, 30)}...`);
    } else {
      console.log(`⚠️ Skipped duplicate: ${q.content.substring(0, 30)}...`);
    }
  }

  console.log('🎉 AWS Test Seed completed successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
