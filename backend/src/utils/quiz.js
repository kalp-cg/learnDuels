/**
 * Quiz Generation Utilities
 * Functions for generating random quizzes and selecting questions
 */

const { prisma } = require('../config/db');

/**
 * Generate random quiz based on criteria
 * @param {Object} criteria - Quiz generation criteria
 * @param {string} [criteria.topicId] - Topic ID to filter by
 * @param {string} [criteria.difficulty] - Difficulty level
 * @param {number} [criteria.count=10] - Number of questions
 * @returns {Promise<Array>} Array of selected questions
 */
async function generateRandomQuiz(criteria = {}) {
  const {
    topicId,
    difficulty,
    count = 10,
  } = criteria;

  try {
    // Build where clause for filtering
    const whereClause = {
      status: 'PUBLISHED',
    };

    // Add difficulty filter
    if (difficulty) {
      whereClause.difficulty = difficulty;
    }

    // Add topic filter
    if (topicId) {
      whereClause.topics = {
        some: {
          topicId: topicId,
        },
      };
    }

    // Get random questions
    const questions = await prisma.question.findMany({
      where: whereClause,
      include: {
        author: {
          select: {
            id: true,
            username: true,
          },
        },
        topics: {
          include: {
            topic: {
              select: {
                id: true,
                name: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: count * 3, // Get more than needed for randomization
    });

    // Shuffle and select the required count
    const shuffledQuestions = shuffleArray(questions);
    const selectedQuestions = shuffledQuestions.slice(0, count);

    return selectedQuestions;
  } catch (error) {
    console.error('Error generating random quiz:', error);
    throw new Error('Failed to generate quiz');
  }
}

/**
 * Select balanced questions across difficulty levels
 * @param {Object} criteria - Selection criteria
 * @param {string} [criteria.topicId] - Topic ID to filter by
 * @param {number} [criteria.count=10] - Total number of questions
 * @param {Object} [criteria.distribution] - Difficulty distribution
 * @returns {Promise<Array>} Array of balanced questions
 */
async function selectBalancedQuestions(criteria = {}) {
  const {
    topicId,
    count = 10,
    distribution = { EASY: 0.4, MEDIUM: 0.4, HARD: 0.2 },
  } = criteria;

  try {
    const results = [];
    
    // Calculate counts for each difficulty
    const easyCounts = Math.floor(count * distribution.EASY);
    const mediumCounts = Math.floor(count * distribution.MEDIUM);
    const hardCounts = count - easyCounts - mediumCounts;

    // Get questions for each difficulty
    for (const [difficulty, targetCount] of [
      ['EASY', easyCounts],
      ['MEDIUM', mediumCounts],
      ['HARD', hardCounts],
    ]) {
      if (targetCount > 0) {
        const questions = await generateRandomQuiz({
          topicId,
          difficulty,
          count: targetCount,
        });
        
        results.push(...questions);
      }
    }

    // Shuffle the final result
    return shuffleArray(results);
  } catch (error) {
    console.error('Error selecting balanced questions:', error);
    throw new Error('Failed to select balanced questions');
  }
}

/**
 * Get questions for duel challenge
 * @param {Object} settings - Challenge settings
 * @returns {Promise<Array>} Array of duel questions
 */
async function getDuelQuestions(settings) {
  const {
    topicId,
    difficulty,
    questionCount = 10,
    timeLimit,
  } = settings;

  try {
    // For duels, we want consistent difficulty
    const questions = await generateRandomQuiz({
      topicId,
      difficulty,
      count: questionCount,
    });

    // Format questions for duel (remove correct answer for client)
    const duelQuestions = questions.map(question => ({
      id: question.id,
      content: question.content,
      options: question.options,
      timeLimit: timeLimit || question.timeLimit,
      difficulty: question.difficulty,
      topics: question.topics.map(tq => tq.topic),
    }));

    return duelQuestions;
  } catch (error) {
    console.error('Error getting duel questions:', error);
    throw new Error('Failed to get duel questions');
  }
}

/**
 * Validate question answers
 * @param {Array} questions - Questions with correct answers
 * @param {Array} userAnswers - User submitted answers
 * @returns {Object} Validation results
 */
function validateAnswers(questions, userAnswers) {
  let correctCount = 0;
  let totalScore = 0;
  const results = [];

  questions.forEach((question, index) => {
    const userAnswer = userAnswers[index];
    const isCorrect = userAnswer === question.correctAnswer;
    
    if (isCorrect) {
      correctCount++;
      
      // Score based on difficulty
      const score = getDifficultyScore(question.difficulty);
      totalScore += score;
    }

    results.push({
      questionId: question.id,
      userAnswer,
      correctAnswer: question.correctAnswer,
      isCorrect,
      explanation: question.explanation,
    });
  });

  return {
    correctCount,
    totalQuestions: questions.length,
    totalScore,
    percentage: Math.round((correctCount / questions.length) * 100),
    results,
  };
}

/**
 * Get score based on difficulty
 * @param {string} difficulty - Question difficulty
 * @returns {number} Points for the difficulty
 */
function getDifficultyScore(difficulty) {
  const scores = {
    EASY: 10,
    MEDIUM: 15,
    HARD: 25,
  };
  
  return scores[difficulty] || 10;
}

/**
 * Calculate XP gained from quiz performance
 * @param {Object} results - Quiz results
 * @param {number} timeTaken - Time taken to complete
 * @param {number} timeLimit - Total time limit
 * @returns {number} XP gained
 */
function calculateXP(results, timeTaken, timeLimit) {
  const baseXP = results.totalScore;
  
  // Time bonus (up to 50% bonus for quick completion)
  const timeRatio = timeTaken / timeLimit;
  const timeBonus = timeRatio < 0.5 ? baseXP * 0.5 : 0;
  
  // Accuracy bonus
  const accuracyBonus = results.percentage > 80 ? baseXP * 0.3 : 0;
  
  return Math.floor(baseXP + timeBonus + accuracyBonus);
}

/**
 * Shuffle array using Fisher-Yates algorithm
 * @param {Array} array - Array to shuffle
 * @returns {Array} Shuffled array
 */
function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

/**
 * Get topic hierarchy for quiz generation
 * @param {string} topicId - Topic ID
 * @returns {Promise<Array>} Array of topic IDs including children
 */
async function getTopicHierarchy(topicId) {
  try {
    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
      include: {
        children: {
          include: {
            children: true, // Include grandchildren
          },
        },
      },
    });

    if (!topic) {
      return [topicId];
    }

    const topicIds = [topicId];
    
    // Add children
    topic.children.forEach(child => {
      topicIds.push(child.id);
      // Add grandchildren
      child.children.forEach(grandchild => {
        topicIds.push(grandchild.id);
      });
    });

    return topicIds;
  } catch (error) {
    console.error('Error getting topic hierarchy:', error);
    return [topicId];
  }
}

module.exports = {
  generateRandomQuiz,
  selectBalancedQuestions,
  getDuelQuestions,
  validateAnswers,
  getDifficultyScore,
  calculateXP,
  shuffleArray,
  getTopicHierarchy,
};