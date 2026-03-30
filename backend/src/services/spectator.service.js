const prisma = require('../config/db');

/**
 * SPECTATOR MODE SERVICE
 * 
 * Allows users to watch live duels in real-time
 * Features:
 * - Join/leave spectating
 * - Real-time score updates
 * - Question progression
 * - Chat for spectators
 */

class SpectatorService {
  constructor() {
    this.activeDuels = new Map(); // duelId -> { participants, spectators, currentQuestion }
    this.spectatorSockets = new Map(); // socketId -> { userId, duelId }
  }

  /**
   * Join a duel as spectator
   * @param {number} duelId - Duel ID
   * @param {number} userId - Spectator user ID
   * @param {string} socketId - Socket ID
   * @returns {Promise<Object>} Duel state
   */
  async joinSpectate(duelId, userId, socketId) {
    // Verify duel exists and is in progress
    const duel = await prisma.duel.findUnique({
      where: { id: duelId },
      include: {
        creator: { select: { id: true, username: true, avatarUrl: true, level: true } },
        opponent: { select: { id: true, username: true, avatarUrl: true, level: true } },
        questionSet: {
          include: {
            items: {
              include: {
                question: {
                  select: {
                    id: true,
                    question: true,
                    options: true,
                    difficulty: true
                  }
                }
              },
              orderBy: { order: 'asc' }
            }
          }
        },
        answers: {
          include: {
            user: { select: { username: true } }
          }
        }
      }
    });

    if (!duel) {
      throw new Error('Duel not found');
    }

    if (duel.status !== 'in_progress' && duel.status !== 'completed') {
      throw new Error('Cannot spectate duel that is not in progress');
    }

    // Check if user is a participant
    if (duel.creatorId === userId || duel.opponentId === userId) {
      throw new Error('Participants cannot spectate their own duel');
    }

    // Initialize duel tracking if not exists
    if (!this.activeDuels.has(duelId)) {
      this.activeDuels.set(duelId, {
        participants: [duel.creatorId, duel.opponentId],
        spectators: new Set(),
        currentQuestion: 0,
        scores: {
          [duel.creatorId]: 0,
          [duel.opponentId]: 0
        }
      });
    }

    const duelState = this.activeDuels.get(duelId);
    duelState.spectators.add(userId);

    // Track socket mapping
    this.spectatorSockets.set(socketId, { userId, duelId });

    // Calculate current scores
    const creatorScore = duel.answers.filter(a => a.userId === duel.creatorId && a.isCorrect).length;
    const opponentScore = duel.answers.filter(a => a.userId === duel.opponentId && a.isCorrect).length;

    return {
      duel: {
        id: duel.id,
        status: duel.status,
        creator: duel.creator,
        opponent: duel.opponent,
        currentQuestion: duelState.currentQuestion,
        totalQuestions: duel.questionSet.items.length,
        scores: {
          [duel.creatorId]: creatorScore,
          [duel.opponentId]: opponentScore
        }
      },
      spectatorCount: duelState.spectators.size,
      questions: duel.questionSet.items.map(item => ({
        id: item.question.id,
        question: item.question.question,
        options: item.question.options,
        difficulty: item.question.difficulty
      }))
    };
  }

  /**
   * Leave spectating
   * @param {string} socketId - Socket ID
   */
  leaveSpectate(socketId) {
    const spectatorData = this.spectatorSockets.get(socketId);
    if (!spectatorData) return;

    const { userId, duelId } = spectatorData;
    const duelState = this.activeDuels.get(duelId);
    
    if (duelState) {
      duelState.spectators.delete(userId);
      
      // Clean up if no spectators left
      if (duelState.spectators.size === 0) {
        this.activeDuels.delete(duelId);
      }
    }

    this.spectatorSockets.delete(socketId);
  }

  /**
   * Update spectators when answer is submitted
   * @param {number} duelId - Duel ID
   * @param {number} userId - User who answered
   * @param {boolean} isCorrect - Answer correctness
   * @param {number} questionIndex - Question index
   * @returns {Object} Update payload
   */
  notifySpectators(duelId, userId, isCorrect, questionIndex) {
    const duelState = this.activeDuels.get(duelId);
    if (!duelState) return null;

    // Update scores
    if (isCorrect) {
      duelState.scores[userId] = (duelState.scores[userId] || 0) + 1;
    }

    // Update question progress
    duelState.currentQuestion = Math.max(duelState.currentQuestion, questionIndex + 1);

    return {
      duelId,
      userId,
      isCorrect,
      questionIndex,
      scores: duelState.scores,
      currentQuestion: duelState.currentQuestion,
      spectatorCount: duelState.spectators.size
    };
  }

  /**
   * Get list of spectatable duels
   * @param {number} limit - Max duels to return
   * @returns {Promise<Array>} Active duels
   */
  async getSpectatableDuels(limit = 20) {
    const duels = await prisma.duel.findMany({
      where: {
        status: 'in_progress'
      },
      include: {
        creator: { select: { username: true, avatarUrl: true, level: true } },
        opponent: { select: { username: true, avatarUrl: true, level: true } }
      },
      orderBy: { startedAt: 'desc' },
      take: limit
    });

    return duels.map(duel => ({
      id: duel.id,
      creator: duel.creator,
      opponent: duel.opponent,
      startedAt: duel.startedAt,
      spectatorCount: this.activeDuels.get(duel.id)?.spectators.size || 0
    }));
  }

  /**
   * Get spectators for a duel
   * @param {number} duelId - Duel ID
   * @returns {Promise<Array>} Spectator list
   */
  async getSpectators(duelId) {
    const duelState = this.activeDuels.get(duelId);
    if (!duelState) return [];

    const spectatorIds = Array.from(duelState.spectators);
    const spectators = await prisma.user.findMany({
      where: { id: { in: spectatorIds } },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        level: true
      }
    });

    return spectators;
  }

  /**
   * End duel spectating (cleanup)
   * @param {number} duelId - Duel ID
   */
  endDuelSpectating(duelId) {
    this.activeDuels.delete(duelId);
    
    // Remove all socket mappings for this duel
    for (const [socketId, data] of this.spectatorSockets.entries()) {
      if (data.duelId === duelId) {
        this.spectatorSockets.delete(socketId);
      }
    }
  }
}

module.exports = new SpectatorService();
