const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Attempt Service - Tracks quiz/questionSet attempts and results
 * PRD Requirement: Generic attempt tracking for quizzes
 */

class AttemptService {
  /**
   * Start a new attempt
   */
  async startAttempt(userId, questionSetId) {
    // Validate question set
    const questionSet = await prisma.questionSet.findUnique({
      where: { id: parseInt(questionSetId) },
    });

    if (!questionSet) {
      throw new Error('Question set not found');
    }

    // Check visibility
    if (questionSet.visibility === 'private' && questionSet.authorId !== userId) {
      throw new Error('Access denied');
    }

    // Create attempt
    const attempt = await prisma.attempt.create({
      data: {
        userId,
        questionSetId: parseInt(questionSetId),
        answers: [],
        score: 0,
        timeTaken: 0,
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
          },
        },
        questionSet: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    return attempt;
  }

  /**
   * Start a practice attempt (no question set)
   */
  async startPracticeAttempt(userId, topicId, difficulty, limit = 10) {
    const fetchLimit = Math.max(limit, 20); // Fetch enough questions for shuffling

    // 1. Fetch questions matching the difficulty
    const questions = await prisma.question.findMany({
      where: {
        topics: {
          some: {
            topicId: parseInt(topicId)
          }
        },
        difficulty: difficulty ? difficulty.toLowerCase() : undefined,
        status: 'published',
        deletedAt: null,
      },
      take: fetchLimit,
      orderBy: {
        createdAt: 'desc'
      }
    });

    // 2. If we don't have enough questions to satisfy the limit (or the fetchLimit buffer), 
    // fetch more from other difficulties to fill the gap.
    if (questions.length < fetchLimit) {
      const existingIds = questions.map(q => q.id);
      const remainingToFetch = fetchLimit - questions.length;

      const moreQuestions = await prisma.question.findMany({
        where: {
          topics: {
            some: {
              topicId: parseInt(topicId)
            }
          },
          id: {
            notIn: existingIds
          },
          status: 'published',
          deletedAt: null,
        },
        // Fetch up to the remaining buffer size
        take: remainingToFetch,
        orderBy: {
          createdAt: 'desc'
        }
      });
      
      questions.push(...moreQuestions);
    }
      
    if (questions.length === 0) {
       throw new Error('No questions found for this topic. Please add questions first.');
    }

    // Shuffle and take requested number of questions
    const shuffled = questions.sort(() => Math.random() - 0.5);
    const selectedQuestions = shuffled.slice(0, Math.min(limit, shuffled.length));

    const attempt = await prisma.attempt.create({
      data: {
        userId,
        answers: [],
        score: 0,
        timeTaken: 0,
      },
    });

    return {
      attemptId: attempt.id,
      questions: selectedQuestions.map(q => ({
        id: q.id,
        content: q.content,
        options: q.options,
        type: q.type,
        difficulty: q.difficulty,
        explanation: q.explanation,
        correctAnswer: q.correctAnswer, // Include for debugging (don't send to prod frontend)
      })),
    };
  }

  /**
   * Submit an answer during attempt
   */
  async submitAnswer(attemptId, userId, answerData) {
    const { questionId, answerIndex, timeTaken } = answerData;

    // Get attempt
    const attempt = await prisma.attempt.findUnique({
      where: { id: parseInt(attemptId) },
    });

    if (!attempt) {
      throw new Error('Attempt not found');
    }

    if (attempt.userId !== userId) {
      throw new Error('Access denied');
    }

    // Get question to check answer
    const question = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!question) {
      throw new Error('Question not found');
    }

    // Determine selected answer from index
    let selectedAnswer;
    let selectedAnswerId;
    let isCorrect = false;

    if (Array.isArray(question.options) && typeof answerIndex === 'number') {
        const option = question.options[answerIndex];
        if (typeof option === 'object' && option !== null) {
            selectedAnswer = option.text || String(option.id);
            selectedAnswerId = option.id;
        } else {
            selectedAnswer = String(option);
            selectedAnswerId = option;
        }
    } else {
        selectedAnswer = answerData.selectedAnswer; // Fallback
    }

    // Check correctness
    // Case 1: correctAnswer matches the Option ID (e.g., "A", "true", "false")
    if (selectedAnswerId && String(question.correctAnswer) === String(selectedAnswerId)) {
        isCorrect = true;
    }
    // Case 2: correctAnswer matches the Option Text (legacy/fallback)
    else if (String(question.correctAnswer) === String(selectedAnswer)) {
        isCorrect = true;
    } 
    // Case 3: correctAnswer matches the index (legacy/fallback)
    else if (question.correctAnswer == answerIndex) { 
        isCorrect = true;
    }

    // Add answer to attempt
    // answers is a JSON field, so we need to handle it as an array
    const currentAnswers = Array.isArray(attempt.answers) ? attempt.answers : [];
    
    const updatedAnswers = [
      ...currentAnswers,
      {
        questionId,
        selectedAnswer,
        answerIndex,
        correctAnswer: question.correctAnswer,
        isCorrect,
        timeTaken,
        answeredAt: new Date(),
      },
    ];

    // Update attempt
    const updatedAttempt = await prisma.attempt.update({
      where: { id: parseInt(attemptId) },
      data: {
        answers: updatedAnswers,
      },
    });

    return {
      isCorrect,
      correctAnswer: question.correctAnswer,
      attempt: updatedAttempt,
    };
  }

  /**
   * Complete an attempt
   */
  async completeAttempt(attemptId, userId) {
    const attempt = await prisma.attempt.findUnique({
      where: { id: parseInt(attemptId) },
    });

    if (!attempt) {
      throw new Error('Attempt not found');
    }

    if (attempt.userId !== userId) {
      throw new Error('Access denied');
    }

    // Calculate score
    const answers = Array.isArray(attempt.answers) ? attempt.answers : [];
    const correctCount = answers.filter(a => a.isCorrect).length;
    const totalQuestions = answers.length;
    
    // Simple scoring: 10 points per correct answer
    const score = correctCount * 10;
    
    // Calculate total time
    const totalTime = answers.reduce((acc, curr) => acc + (curr.timeTaken || 0), 0);

    // Update attempt
    const completedAttempt = await prisma.attempt.update({
      where: { id: parseInt(attemptId) },
      data: {
        score,
        timeTaken: totalTime,
      },
    });

    // Award XP and update stats
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (user) {
      const newXp = user.xp + score;
      const newLevel = Math.floor(newXp / 100) + 1; // Simple level formula: 100 XP per level

      await prisma.user.update({
        where: { id: userId },
        data: {
          xp: newXp,
          level: newLevel,
          questionsSolved: { increment: correctCount },
          quizzesCompleted: { increment: 1 },
          rating: { increment: 10 + correctCount } // Simple rating logic
        }
      });
    }

    return completedAttempt;
  }

  /**
   * Get user attempts
   */
  async getUserAttempts(userId, filters = {}) {
    const { page = 1, limit = 20 } = filters;
    const skip = (page - 1) * limit;

    const [attempts, total] = await Promise.all([
      prisma.attempt.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          questionSet: {
            select: {
              name: true,
            },
          },
        },
      }),
      prisma.attempt.count({ where: { userId } }),
    ]);

    return {
      data: attempts,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get user attempt stats
   */
  async getUserAttemptStats(userId) {
    const attempts = await prisma.attempt.findMany({
      where: { userId },
      select: {
        score: true,
        answers: true,
      },
    });

    const totalAttempts = attempts.length;
    const totalScore = attempts.reduce((acc, curr) => acc + curr.score, 0);
    
    let totalQuestionsAnswered = 0;
    let totalCorrectAnswers = 0;

    attempts.forEach(a => {
      const answers = Array.isArray(a.answers) ? a.answers : [];
      totalQuestionsAnswered += answers.length;
      totalCorrectAnswers += answers.filter(ans => ans.isCorrect).length;
    });

    const accuracy = totalQuestionsAnswered > 0 
      ? (totalCorrectAnswers / totalQuestionsAnswered) * 100 
      : 0;

    return {
      totalAttempts,
      totalScore,
      totalQuestionsAnswered,
      totalCorrectAnswers,
      accuracy: parseFloat(accuracy.toFixed(2)),
    };
  }

  /**
   * Get attempt by ID
   */
  async getAttemptById(attemptId, userId) {
    const attempt = await prisma.attempt.findUnique({
      where: { id: parseInt(attemptId) },
      include: {
        questionSet: {
          select: {
            name: true,
            items: {
              include: {
                question: true
              }
            }
          },
        },
      },
    });

    if (!attempt) {
      throw new Error('Attempt not found');
    }

    if (attempt.userId !== userId) {
      throw new Error('Access denied');
    }

    return attempt;
  }
}

module.exports = new AttemptService();
