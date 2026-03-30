/**
 * Duel Service
 * Handles duel creation, management, and scoring
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');
const questionService = require('./question.service');
const feedService = require('./feed.service');
const userService = require('./user.service');
const leaderboardService = require('./leaderboard.service');
const { deleteCachePattern } = require('../config/redis');

/**
 * Transform question to match frontend expectations (Old Schema)
 */
/**
 * Transform question to match frontend expectations (Unified Schema)
 */
function transformQuestion(q) {
  if (q && q.content && Array.isArray(q.options)) {
    // Return unified format: content + options array
    return {
      ...q,
      questionText: q.content, // Keep alias for compatibility if needed, but prefer content
      options: q.options, // Pass through the original options array (id, text)
      correctOption: q.correctAnswer,
    };
  }
  return q;
}

/**
 * Create a new duel
 */
async function createDuel(player1Id, player2Id, settings = {}) {
  try {
    const { categoryId, difficultyId, questionCount = 7 } = settings;

    // Create challenge first (Required by schema)
    const challenge = await prisma.challenge.create({
      data: {
        challengerId: parseInt(player1Id),
        type: 'instant',
        settings: settings || {},
        status: 'active',
        participants: {
          create: [
            { userId: parseInt(player1Id), status: 'accepted' },
            { userId: parseInt(player2Id), status: 'accepted' }
          ]
        }
      }
    });

    // Create duel linked to challenge
    const duel = await prisma.duel.create({
      data: {
        challengeId: challenge.id,
        player1Id: parseInt(player1Id),
        player2Id: parseInt(player2Id),
        status: 'pending',
      },
      include: {
        player1: {
          select: {
            id: true,
            fullName: true,
            email: true,
            avatarUrl: true,
            rating: true,
          },
        },
        player2: {
          select: {
            id: true,
            fullName: true,
            email: true,
            avatarUrl: true,
            rating: true,
          },
        },
      },
    });

    // Get random questions
    const questions = await questionService.getRandomQuestions(
      { categoryId, difficultyId },
      questionCount,
      [player1Id, player2Id]
    );

    // Check if enough questions are available
    if (!questions || questions.length === 0) {
      // Delete the duel if no questions found
      await prisma.duel.delete({ where: { id: duel.id } });
      throw createError.badRequest(
        'No questions available for the selected category and difficulty. Please create questions first.'
      );
    }

    // Add questions to duel
    await Promise.all(
      questions.map((q, index) =>
        prisma.duelQuestion.create({
          data: {
            duelId: duel.id,
            questionId: q.id,
            orderIndex: index + 1,
          },
        })
      )
    );

    // Send notification to player 2
    try {
      const notification = await prisma.notification.create({
        data: {
          userId: parseInt(player2Id),
          message: `${duel.player1.fullName || 'Someone'} challenged you to a duel!`,
          type: 'duel_invite',
          data: { duelId: duel.id, challengeId: challenge.id },
        },
      });

      const { getIO, sendToUser } = require('../sockets/index');
      const io = getIO();
      sendToUser(io, player2Id, 'notification', notification);

      // Send event expected by frontend
      sendToUser(io, player2Id, 'duel:invitation_received', {
        duelId: duel.id,
        challengeId: challenge.id,
        challengerId: duel.player1.id,
        challengerEmail: duel.player1.email,
        challengerName: duel.player1.fullName,
        settings
      });
    } catch (e) {
      console.error('Failed to send duel notification:', e);
    }

    return {
      ...duel,
      questions: questions.map(transformQuestion),
    };
  } catch (error) {
    console.error('Create duel error:', error);
    throw createError.internal(`Failed to create duel: ${error.message}`);
  }
}

/**
 * Get duel by ID
 */
async function getDuelById(duelId) {
  try {
    const duel = await prisma.duel.findUnique({
      where: { id: parseInt(duelId) },
      include: {
        player1: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
        player2: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
        duelQuestions: {
          include: {
            question: true,
          },
        },
        duelAnswers: {
          include: {
            player: {
              select: {
                id: true,
                fullName: true,
              },
            },
          },
        },
      },
    });

    if (!duel) {
      throw createError.notFound('Duel not found');
    }

    // Transform duelQuestions to questions array
    const questions = duel.duelQuestions
      .sort((a, b) => a.orderIndex - b.orderIndex)
      .map((dq) => transformQuestion(dq.question));

    const { duelQuestions, ...duelData } = duel;
    return {
      ...duelData,
      questions,
    };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to fetch duel');
  }
}

/**
 * Get duel by Challenge ID
 */
async function getDuelByChallengeId(challengeId) {
  try {
    console.log(`DEBUG: Fetching duel for challengeId: ${challengeId} (type: ${typeof challengeId})`);
    const duel = await prisma.duel.findFirst({
      where: { challengeId: parseInt(challengeId) },
      include: {
        player1: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
        player2: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
        duelQuestions: {
          include: {
            question: true,
          },
        },
      },
    });

    if (!duel) {
      console.log(`DEBUG: No duel found for challengeId: ${challengeId}`);
      return null;
    }

    console.log(`DEBUG: Found duel ID: ${duel.id}. Questions count: ${duel.duelQuestions.length}`);

    // Transform duelQuestions to questions array
    const questions = duel.duelQuestions
      .sort((a, b) => a.orderIndex - b.orderIndex)
      .map((dq) => transformQuestion(dq.question));

    const { duelQuestions, ...duelData } = duel;
    return {
      ...duelData,
      questions,
    };
  } catch (error) {
    console.error('Get duel by challenge ID error:', error);
    throw createError.internal('Failed to fetch duel by challenge ID');
  }
}

/**
 * Get user's duels
 */
async function getUserDuels(userId, options = {}) {
  const { page = 1, limit = 20, status } = options;
  const skip = (page - 1) * limit;

  try {
    const where = {
      OR: [
        { player1Id: parseInt(userId) },
        { player2Id: parseInt(userId) },
      ],
    };

    if (status) where.status = status;

    const [duels, totalCount] = await Promise.all([
      prisma.duel.findMany({
        where,
        include: {
          player1: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
            },
          },
          player2: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
            },
          },
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.duel.count({ where }),
    ]);

    return {
      duels,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to fetch duels');
  }
}

/**
 * Submit answer to duel question
 */
async function submitAnswer(duelId, playerId, questionId, selectedOption, timeTaken = 0) {
  try {
    // Handle skipped/null answer
    const isSkipped = !selectedOption || selectedOption === '';

    // Get question to check correct answer
    const question = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!question) {
      throw createError.notFound('Question not found');
    }

    // Skipped answers are always wrong
    const dbAnswer = question.correctAnswer ? question.correctAnswer.toString().trim().toUpperCase() : '';
    const userAnswer = selectedOption ? selectedOption.toString().trim().toUpperCase() : '';

    console.log(`[DEBUG_ROBUST] Q=${questionId} | DB="${dbAnswer}" | User="${userAnswer}"`);
    const isCorrect = isSkipped ? false : dbAnswer === userAnswer;

    // Save answer
    const answer = await prisma.duelAnswer.create({
      data: {
        duelId: parseInt(duelId),
        playerId: parseInt(playerId),
        questionId: parseInt(questionId),
        selectedAnswer: isSkipped ? 'SKIPPED' : selectedOption,
        isCorrect,
        timeTaken,
      },
    });

    // Check if duel is complete
    await checkDuelCompletion(duelId);

    return {
      answer,
      isCorrect,
      isSkipped,
    };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to submit answer');
  }
}

/**
 * Check if duel is complete and update status
 */
async function checkDuelCompletion(duelId) {
  try {
    const duel = await prisma.duel.findUnique({
      where: { id: parseInt(duelId) },
      include: {
        duelQuestions: true,
        duelAnswers: true,
      },
    });

    const totalQuestions = duel.duelQuestions.length;
    const player1Answers = duel.duelAnswers.filter(
      (a) => a.playerId === duel.player1Id
    ).length;
    const player2Answers = duel.duelAnswers.filter(
      (a) => a.playerId === duel.player2Id
    ).length;

    // Both players answered all questions
    if (player1Answers === totalQuestions && player2Answers === totalQuestions) {
      const player1Score = duel.duelAnswers.filter(
        (a) => a.playerId === duel.player1Id && a.isCorrect
      ).length;
      const player2Score = duel.duelAnswers.filter(
        (a) => a.playerId === duel.player2Id && a.isCorrect
      ).length;

      const winnerId =
        player1Score > player2Score
          ? duel.player1Id
          : player2Score > player1Score
            ? duel.player2Id
            : null; // Tie

      await prisma.duel.update({
        where: { id: parseInt(duelId) },
        data: {
          status: 'completed',
          winnerId,
          completedAt: new Date(),
        },
      });

      // Update leaderboard
      if (winnerId) {
        const winningScore = player1Score > player2Score ? player1Score : player2Score;
        await updateLeaderboard(winnerId, winningScore);

        // Add to activity feed
        try {
          const opponentId = winnerId === duel.player1Id ? duel.player2Id : duel.player1Id;
          await feedService.createActivity(winnerId, 'DUEL_WON', {
            duelId: duel.id,
            opponentId: opponentId,
            score: winningScore
          });
        } catch (feedError) {
          console.error('Failed to create feed activity for duel win:', feedError);
          // Don't fail the duel completion if feed fails
        }
      }
    }
  } catch (error) {
    console.error('Check duel completion error:', error);
  }
}

/**
 * Update leaderboard after duel
 */
async function updateLeaderboard(userId, score) {
  try {
    // Update leaderboard stats (Daily, Weekly, Monthly, All-time)
    await leaderboardService.updateLeaderboardStats(userId, score, true);

    // Update user rating
    await prisma.user.update({
      where: { id: parseInt(userId) },
      data: {
        rating: {
          increment: score * 10,
        },
      },
    });

    // Add XP
    await userService.addXp(userId, score * 5);
  } catch (error) {
    console.error('Update leaderboard error:', error);
  }
}

/**
 * Get duel questions (without correct answers)
 */
async function getDuelQuestions(duelId, playerId) {
  try {
    const duel = await prisma.duel.findUnique({
      where: { id: parseInt(duelId) },
    });

    if (!duel) {
      throw createError.notFound('Duel not found');
    }

    // Verify player is part of duel
    if (duel.player1Id !== parseInt(playerId) && duel.player2Id !== parseInt(playerId)) {
      throw createError.forbidden('Not authorized to view this duel');
    }

    const questions = await prisma.duelQuestion.findMany({
      where: { duelId: parseInt(duelId) },
      include: {
        question: {
          select: {
            id: true,
            questionText: true,
            optionA: true,
            optionB: true,
            optionC: true,
            optionD: true,
            // category: true, // removed invalid field
            difficulty: true,
          },
        },
      },
    });

    return questions.map((dq) => dq.question);
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to fetch duel questions');
  }
}

/**
 * Update duel room code
 */
async function updateDuelRoomCode(duelId, roomCode) {
  try {
    return await prisma.duel.update({
      where: { id: parseInt(duelId) },
      data: { roomCode },
    });
  } catch (error) {
    console.error('Update duel room code error:', error);
    throw createError.internal('Failed to update duel room code');
  }
}

/**
 * Find a match (Simple Random Matchmaking)
 */
async function findMatch(userId, categoryId) {
  try {
    // 1. Find a random opponent (not self)
    const count = await prisma.user.count({
      where: {
        id: { not: parseInt(userId) },
        isActive: true
      }
    });

    if (count === 0) {
      throw createError.notFound('No opponents available');
    }

    const skip = Math.floor(Math.random() * count);
    const opponents = await prisma.user.findMany({
      where: {
        id: { not: parseInt(userId) },
        isActive: true
      },
      take: 1,
      skip: skip,
      select: { id: true }
    });

    if (!opponents.length) {
      throw createError.notFound('No opponents available');
    }

    const opponent = opponents[0];

    // 2. Create Duel
    // Defaulting to Medium difficulty (2) and 5 questions
    return await createDuel(userId, opponent.id, {
      categoryId,
      difficultyId: 2,
      questionCount: 5
    });

  } catch (error) {
    console.error('Matchmaking error:', error);
    throw error;
  }
}


module.exports = {
  createDuel,
  getDuelById,
  getDuelByChallengeId,
  getUserDuels,
  submitAnswer,
  getDuelQuestions,
  updateDuelRoomCode,
  findMatch,
};
