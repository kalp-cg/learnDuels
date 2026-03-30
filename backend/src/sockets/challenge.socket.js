/**
 * Challenge Socket Handler - PRD Compliant
 * Handles real-time instant duel challenges (type: "instant")
 * For async challenges, use REST API only
 */

const challengeService = require('../services/challenge.service');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// In-memory state for instant duels (use Redis in production)
const activeRooms = new Map(); // roomId -> room data
const userSockets = new Map(); // userId -> socketId

/**
 * Register challenge event handlers
 * @param {Object} socket - Socket instance
 * @param {Object} io - Socket.IO server instance
 */
function registerEvents(socket, io) {
  console.log(`✅ User ${socket.userId} connected to challenge socket`);

  // Track user socket
  userSockets.set(socket.userId, socket.id);

  // ==================== INSTANT DUEL FLOW ====================

  /**
   * Send instant challenge invitation
   * Client emits: { opponentId, questionSetId, settings }
   */
  socket.on('challenge:invite', async (data) => {
    try {
      const { opponentId, questionSetId, settings = {} } = data;

      console.log(`📨 Challenge invite from ${socket.userId} to ${opponentId}`);

      // Check if opponent is online
      const opponentSocketId = userSockets.get(opponentId);
      if (!opponentSocketId) {
        socket.emit('challenge:error', {
          error: 'Opponent is not online',
          code: 'OPPONENT_OFFLINE',
        });
        return;
      }

      // Create challenge in database
      const challenge = await challengeService.createChallenge(
        {
          opponentIds: [opponentId],
          questionSetId,
          type: 'instant',
          settings: {
            ...settings,
            numQuestions: settings.numQuestions || 10,
            timeLimit: settings.timeLimit || 30,
          },
        },
        socket.userId
      );

      // Send invitation to opponent
      io.to(opponentSocketId).emit('challenge:invitation_received', {
        challengeId: challenge.id,
        challenger: challenge.challenger,
        questionSetId,
        settings: challenge.settings,
        timestamp: new Date().toISOString(),
      });

      // Confirm to sender
      socket.emit('challenge:invitation_sent', {
        challengeId: challenge.id,
        opponentId,
        timestamp: new Date().toISOString(),
      });

      console.log(`✅ Challenge ${challenge.id} invitation sent`);
    } catch (error) {
      console.error('Challenge invite error:', error);
      socket.emit('challenge:error', {
        error: error.message,
        code: 'INVITE_FAILED',
      });
    }
  });

  /**
   * Accept instant challenge
   * Client emits: { challengeId }
   */
  socket.on('challenge:accept', async (data) => {
    try {
      const { challengeId } = data;

      console.log(`✅ User ${socket.userId} accepting challenge ${challengeId}`);

      // Update challenge status
      const challenge = await challengeService.acceptChallenge(challengeId, socket.userId);

      // Get challenge details with questions
      const fullChallenge = await prisma.challenge.findUnique({
        where: { id: challengeId },
        include: {
          challenger: {
            select: { id: true, fullName: true, avatarUrl: true, rating: true },
          },
          questionSet: {
            select: {
              id: true,
              name: true,
              items: {
                select: { questionId: true }
              }
            },
          },
        },
      });

      let questionIds = [];
      if (fullChallenge.questionSet) {
        questionIds = fullChallenge.questionSet.items.map(item => item.questionId);
      } else {
        // Generate random questions based on settings
        const { numQuestions = 10, difficulty = 'medium', topicIds = [] } = fullChallenge.settings || {};

        const where = {
          status: 'published',
        };

        if (difficulty) where.difficulty = difficulty;
        if (topicIds && topicIds.length > 0) {
          where.topicId = { in: topicIds };
        }

        const randomQuestions = await prisma.question.findMany({
          where,
          take: parseInt(numQuestions),
          select: { id: true }
        });

        questionIds = randomQuestions.map(q => q.id);
      }

      // Get questions
      const questions = await prisma.question.findMany({
        where: {
          id: { in: questionIds },
          status: 'published',
        },
        select: {
          id: true,
          content: true,
          options: true,
          difficulty: true,
          timeLimit: true,
          // Don't send correctAnswer to clients yet
        },
      });

      // Create room
      const roomId = `challenge_${challengeId}`;
      const roomData = {
        id: roomId,
        challengeId,
        players: [challenge.challengerId, socket.userId],
        status: 'active',
        currentQuestion: 0,
        questions: questions.map(q => q.id),
        scores: {
          [challenge.challengerId]: 0,
          [socket.userId]: 0,
        },
        answers: {
          [challenge.challengerId]: [],
          [socket.userId]: [],
        },
        startedAt: new Date().toISOString(),
      };

      activeRooms.set(roomId, roomData);

      // Join both players to room
      socket.join(roomId);
      const challengerSocketId = userSockets.get(challenge.challengerId);
      if (challengerSocketId) {
        const challengerSocket = io.sockets.sockets.get(challengerSocketId);
        if (challengerSocket) {
          challengerSocket.join(roomId);
        }
      }

      // Notify both players - send all questions
      io.to(roomId).emit('challenge:started', {
        challengeId,
        roomId,
        players: [
          {
            id: challenge.challengerId,
            name: fullChallenge.challenger.fullName,
            avatar: fullChallenge.challenger.avatarUrl,
            rating: fullChallenge.challenger.rating,
          },
          {
            id: socket.userId,
            name: socket.userName,
            avatar: socket.userAvatar,
            rating: socket.userRating,
          },
        ],
        totalQuestions: questions.length,
        timeLimit: fullChallenge.settings.timeLimit,
        currentQuestion: 0,
        questions: questions.map(q => {
          // Handle options format (array of objects or simple array)
          const opts = Array.isArray(q.options) ? q.options : [];
          return {
            id: q.id,
            questionText: q.content,
            optionA: opts[0]?.text || opts[0] || '',
            optionB: opts[1]?.text || opts[1] || '',
            optionC: opts[2]?.text || opts[2] || '',
            optionD: opts[3]?.text || opts[3] || '',
            timeLimit: q.timeLimit
          };
        }),
      });

      console.log(`🎮 Challenge ${challengeId} started in room ${roomId}`);
    } catch (error) {
      console.error('Challenge accept error:', error);
      socket.emit('challenge:error', {
        error: error.message,
        code: 'ACCEPT_FAILED',
      });
    }
  });

  /**
   * Decline instant challenge
   * Client emits: { challengeId }
   */
  socket.on('challenge:decline', async (data) => {
    try {
      const { challengeId } = data;

      console.log(`❌ User ${socket.userId} declined challenge ${challengeId}`);

      await challengeService.declineChallenge(challengeId, socket.userId);

      // Get challenger info
      const challenge = await prisma.challenge.findUnique({
        where: { id: challengeId },
      });

      // Notify challenger
      const challengerSocketId = userSockets.get(challenge.challengerId);
      if (challengerSocketId) {
        io.to(challengerSocketId).emit('challenge:declined', {
          challengeId,
          opponentId: socket.userId,
          timestamp: new Date().toISOString(),
        });
      }

      socket.emit('challenge:decline_confirmed', { challengeId });
    } catch (error) {
      console.error('Challenge decline error:', error);
      socket.emit('challenge:error', {
        error: error.message,
        code: 'DECLINE_FAILED',
      });
    }
  });

  /**
   * Submit answer during instant challenge
   * Client emits: { challengeId, questionId, selectedAnswer, timeTaken }
   */
  socket.on('challenge:answer', async (data) => {
    try {
      const { challengeId, questionId, selectedAnswer, timeTaken } = data;

      const roomId = `challenge_${challengeId}`;
      const room = activeRooms.get(roomId);

      if (!room) {
        socket.emit('challenge:error', {
          error: 'Challenge room not found',
          code: 'ROOM_NOT_FOUND',
        });
        return;
      }

      // Get correct answer
      const question = await prisma.question.findUnique({
        where: { id: questionId },
        select: { correctAnswer: true },
      });

      const dbAnswer = question.correctAnswer ? question.correctAnswer.toString().trim().toUpperCase() : '';
      const userAnswer = selectedAnswer ? selectedAnswer.toString().trim().toUpperCase() : '';

      console.log(`[CHALLENGE_DEBUG] Q=${questionId} | DB="${dbAnswer}" | User="${userAnswer}"`);
      const isCorrect = dbAnswer === userAnswer;

      // Update room state
      room.answers[socket.userId].push({
        questionId,
        selectedAnswer,
        isCorrect,
        timeTaken,
        answeredAt: new Date().toISOString(),
      });

      if (isCorrect) {
        room.scores[socket.userId] += (1000 - Math.min(timeTaken * 10, 500)); // Dynamic scoring
      }

      // Notify opponent about progress (without revealing answer)
      const opponentId = room.players.find(id => id !== socket.userId);
      const opponentSocketId = userSockets.get(opponentId);
      if (opponentSocketId) {
        io.to(opponentSocketId).emit('challenge:opponent_answered', {
          questionNumber: room.currentQuestion + 1,
          totalQuestions: room.questions.length,
        });
      }

      // Confirm to player (with correct answer)
      socket.emit('challenge:answer_recorded', {
        questionId,
        isCorrect,
        correctAnswer: question.correctAnswer,
        currentScore: room.scores[socket.userId],
      });

      // Check if both players answered this question
      const bothAnswered = room.answers[room.players[0]].length === room.currentQuestion + 1 &&
        room.answers[room.players[1]].length === room.currentQuestion + 1;

      if (bothAnswered) {
        room.currentQuestion++;

        // Check if challenge is complete
        if (room.currentQuestion >= room.questions.length) {
          await endChallenge(io, roomId, challengeId);
        } else {
          // Send next question
          const nextQuestion = await prisma.question.findUnique({
            where: { id: room.questions[room.currentQuestion] },
            select: {
              id: true,
              content: true,
              options: true,
              difficulty: true,
              timeLimit: true,
            },
          });

          io.to(roomId).emit('challenge:next_question', {
            questionNumber: room.currentQuestion + 1,
            totalQuestions: room.questions.length,
            question: nextQuestion,
            scores: room.scores,
          });
        }
      }

      console.log(`📝 Answer recorded for user ${socket.userId} in challenge ${challengeId}`);
    } catch (error) {
      console.error('Challenge answer error:', error);
      socket.emit('challenge:error', {
        error: error.message,
        code: 'ANSWER_FAILED',
      });
    }
  });

  /**
   * Disconnect handling
   */
  socket.on('disconnect', () => {
    console.log(`❌ User ${socket.userId} disconnected from challenge socket`);
    userSockets.delete(socket.userId);

    // Handle active challenges
    activeRooms.forEach((room, roomId) => {
      if (room.players.includes(socket.userId)) {
        // Notify opponent
        const opponentId = room.players.find(id => id !== socket.userId);
        const opponentSocketId = userSockets.get(opponentId);
        if (opponentSocketId) {
          io.to(opponentSocketId).emit('challenge:opponent_disconnected', {
            challengeId: room.challengeId,
            message: 'Your opponent disconnected',
          });
        }
        // Clean up room
        activeRooms.delete(roomId);
      }
    });
  });
}

/**
 * End challenge and calculate results
 */
async function endChallenge(io, roomId, challengeId) {
  const room = activeRooms.get(roomId);
  if (!room) return;

  try {
    // Calculate final results
    const results = room.players.map(playerId => ({
      userId: playerId,
      score: room.scores[playerId],
      answers: room.answers[playerId],
      timeTaken: room.answers[playerId].reduce((sum, a) => sum + a.timeTaken, 0),
    }));

    // Determine winner
    const winner = results.reduce((prev, current) => {
      if (current.score > prev.score) return current;
      if (current.score === prev.score && current.timeTaken < prev.timeTaken) return current;
      return prev;
    });

    // Submit results to service for rating updates
    for (const result of results) {
      await challengeService.submitResult(challengeId, result.userId, {
        score: result.score,
        answers: result.answers,
        timeTaken: result.timeTaken,
      });
    }

    // Get updated challenge with winner
    const challenge = await prisma.challenge.findUnique({
      where: { id: challengeId },
      include: {
        challenger: {
          select: { id: true, fullName: true, rating: true },
        },
      },
    });

    // Notify both players
    io.to(roomId).emit('challenge:completed', {
      challengeId,
      winnerId: winner.userId,
      results: results.map(r => ({
        userId: r.userId,
        score: r.score,
        timeTaken: r.timeTaken,
        isWinner: r.userId === winner.userId,
      })),
      finalScores: room.scores,
      timestamp: new Date().toISOString(),
    });

    // Clean up room
    activeRooms.delete(roomId);

    console.log(`🏁 Challenge ${challengeId} completed. Winner: ${winner.userId}`);
  } catch (error) {
    console.error('End challenge error:', error);
    io.to(roomId).emit('challenge:error', {
      error: 'Failed to end challenge',
      code: 'END_FAILED',
    });
  }
}

/**
 * Get active rooms (for debugging)
 */
function getActiveRooms() {
  return Array.from(activeRooms.values());
}

/**
 * Get user's active challenge
 */
function getUserChallenge(userId) {
  for (const [roomId, room] of activeRooms.entries()) {
    if (room.players.includes(userId)) {
      return { roomId, ...room };
    }
  }
  return null;
}

module.exports = {
  registerEvents,
  getActiveRooms,
  getUserChallenge,
};
