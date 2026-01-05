const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
// const { getIO, sendToUser } = require('../sockets/index'); // Moved to lazy load to avoid circular dependency

/**
 * Challenge Service - Handles both async and instant (real-time) challenges
 * PRD Requirement: Asynchronous and instant duel challenges
 */
const questionService = require('./question.service');


class ChallengeService {
  /**
   * Create a challenge (async or instant)
   */
  async createChallenge(data, challengerId) {
    const {
      opponentIds = [],
      questionSetId,
      type = 'async', // 'async' or 'instant'
      settings = {},
    } = data;

    // Validate opponents exist
    console.log('DEBUG: createChallenge challengerId:', challengerId);
    console.log(`DEBUG: createChallenge opponentIds (raw):`, opponentIds);
    const idList = opponentIds.map(id => parseInt(id));
    console.log(`DEBUG: createChallenge idList (ints):`, idList);
    const opponents = await prisma.user.findMany({
      where: { id: { in: idList } },
    });
    console.log(`DEBUG: Found ${opponents.length} opponents`);

    if (opponents.length === 0) {
      const someUsers = await prisma.user.findMany({ take: 5 });
      console.log(`DEBUG: Existing Users IDs in DB:`, someUsers.map(u => u.id));
    }

    if (opponents.length !== opponentIds.length) {
      throw new Error('Some opponents not found');
    }

    // Validate question set if provided
    let questionSet = null;
    if (questionSetId) {
      questionSet = await prisma.questionSet.findUnique({
        where: { id: questionSetId },
      });

      if (!questionSet) {
        throw new Error('Question set not found');
      }
    }

    // Default settings
    const defaultSettings = {
      numQuestions: settings.numQuestions || settings.questionCount || 10,
      questionCount: settings.questionCount || settings.numQuestions || 10, // Ensure compatibility
      timeLimit: settings.timeLimit || 30, // seconds per question
      topicIds: settings.topicIds || [],
      difficulty: settings.difficulty || 'medium',
      allowSpectators: settings.allowSpectators || false,
    };

    const challenge = await prisma.challenge.create({
      data: {
        challengerId,
        questionSetId,
        type,
        settings: defaultSettings,
        status: 'pending',
        participants: {
          create: [
            {
              userId: challengerId,
              status: 'accepted'
            },
            ...opponentIds.map(id => ({
              userId: id,
              status: 'invited'
            }))
          ]
        }
      },
      include: {
        challenger: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
            rating: true,
          },
        },
      },
    });

    // Create notifications for opponents
    await Promise.all(
      opponentIds.map(async (opponentId) => {
        const notification = await prisma.notification.create({
          data: {
            userId: opponentId,
            message: `${challenge.challenger.fullName || 'Someone'} challenged you to a ${type} duel!`,
            type: 'challenge_received',
            data: { challengeId: challenge.id },
          },
        });

        // Send real-time notification
        try {
          const { getIO, sendToUser } = require('../sockets/index');
          const io = getIO();
          sendToUser(io, opponentId, 'notification', notification);

          // Also emit specific challenge event
          sendToUser(io, opponentId, 'challenge:received', {
            challengeId: challenge.id,
            challenger: challenge.challenger,
            type: type,
            settings: defaultSettings
          });
        } catch (e) {
          console.error('Socket notification failed:', e.message);
        }
      })
    );

    return challenge;
  }

  /**
   * Get challenge by ID
   */
  async getChallengeById(id, userId) {
    const challenge = await prisma.challenge.findUnique({
      where: { id: parseInt(id) },
      include: {
        participants: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                avatarUrl: true,
                rating: true,
              },
            },
          },
        },
        challenger: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
            rating: true,
          },
        },
        questionSet: {
          select: {
            id: true,
            name: true,
            items: {
              select: {
                questionId: true,
              },
            },
          },
        },
      },
    });

    if (!challenge) {
      throw new Error('Challenge not found');
    }

    // Check if user is participant
    const isParticipant =
      challenge.challengerId === parseInt(userId) ||
      challenge.participants.some((p) => p.userId === parseInt(userId));

    if (!isParticipant && !challenge.settings.allowSpectators) {
      throw new Error('Access denied');
    }

    return {
      ...challenge,
      isParticipant,
    };
  }

  /**
   * Accept a challenge (for async challenges)
   */
  async acceptChallenge(id, userId) {
    const challenge = await prisma.challenge.findUnique({
      where: { id: parseInt(id) },
      include: {
        participants: true,
      },
    });

    if (!challenge) {
      throw new Error('Challenge not found');
    }

    // Check if user is an opponent
    const participant = challenge.participants.find((p) => p.userId === parseInt(userId));
    if (!participant) {
      throw new Error('You are not invited to this challenge');
    }

    // Update participant status
    await prisma.challengeParticipant.update({
      where: { id: participant.id },
      data: { status: 'accepted' },
    });

    // Update challenge status if it was pending
    const updated = await prisma.challenge.update({
      where: { id: parseInt(id) },
      data: {
        status: 'active',
      },
    });

    // Notify challenger
    await prisma.notification.create({
      data: {
        userId: challenge.challengerId,
        message: 'Your challenge was accepted!',
        type: 'challenge_accepted',
        data: { challengeId: challenge.id },
      },
    });

    // Create Duel if not exists (Upgrade to Real-time Game)
    let duel = await prisma.duel.findUnique({ where: { challengeId: parseInt(id) } });

    if (!duel) {
      console.log(`DEBUG: Creating Duel for Accepted Challenge ${id}`);

      // 1. Get Questions
      let questions = [];
      if (challenge.questionSetId) {
        const qSet = await prisma.questionSet.findUnique({
          where: { id: challenge.questionSetId },
          include: { items: { include: { question: true } } }
        });
        questions = qSet ? qSet.items.map(i => i.question) : [];
      } else {
        const { topicIds, difficulty, questionCount } = challenge.settings || {};
        const categoryId = topicIds && topicIds.length > 0 ? topicIds[0] : null;

        questions = await questionService.getRandomQuestions({
          categoryId,
          difficultyId: difficulty
        }, questionCount || 5, [challenge.challengerId, participant.userId]);
      }

      if (questions.length > 0) {
        // 2. Create Duel
        // Note: For multi-player challenges, this simple model assumes 1v1 (challenger vs acceptor)
        // If multiple serve acceptors, we might need multiple duels or a multi-player duel model.
        // Current Schema has player1Id, player2Id.
        duel = await prisma.duel.create({
          data: {
            challengeId: challenge.id,
            player1Id: challenge.challengerId,
            player2Id: participant.userId,
            status: 'active'
          }
        });

        // 3. Link Questions
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
        console.log(`DEBUG: Created Duel ${duel.id} with ${questions.length} questions`);
      } else {
        console.warn(`WARN: No questions found for Challenge ${id}, Duel not created.`);
      }
    }

    return { ...updated, duelId: duel ? duel.id : null };
  }

  /**
   * Decline a challenge
   */
  async declineChallenge(id, userId) {
    const challenge = await prisma.challenge.findUnique({
      where: { id: parseInt(id) },
      include: {
        participants: true,
      },
    });

    if (!challenge) {
      throw new Error('Challenge not found');
    }

    const participant = challenge.participants.find((p) => p.userId === parseInt(userId));
    if (!participant) {
      throw new Error('You are not invited to this challenge');
    }

    await prisma.challengeParticipant.update({
      where: { id: participant.id },
      data: { status: 'declined' },
    });

    // If it's a 1v1 and opponent declines, maybe mark challenge as declined
    await prisma.challenge.update({
      where: { id: parseInt(id) },
      data: { status: 'declined' },
    });

    await prisma.notification.create({
      data: {
        userId: challenge.challengerId,
        message: 'Your challenge was declined.',
        type: 'challenge_declined',
        data: { challengeId: challenge.id },
      },
    });

    return { message: 'Challenge declined' };
  }

  /**
   * Submit challenge result (for async challenges)
   */
  async submitResult(id, userId, resultData) {
    const challenge = await prisma.challenge.findUnique({
      where: { id: parseInt(id) },
      include: {
        participants: true,
      },
    });

    if (!challenge) {
      throw new Error('Challenge not found');
    }

    // Check if user is participant
    console.log(`DEBUG: submitResult challengeId: ${challenge.id}, userId: ${userId}`);
    const participant = challenge.participants.find((p) => p.userId === parseInt(userId));
    if (!participant) {
      console.error(`DEBUG: Participant not found for user ${userId} in challenge ${challenge.id}. Participants:`, challenge.participants.map(p => p.userId));
      throw new Error('Access denied');
    }

    // Check if user already submitted
    if (participant.completedAt) {
      throw new Error('You have already submitted your result');
    }

    const { score, timeTaken } = resultData;

    // Update participant result
    await prisma.challengeParticipant.update({
      where: { id: participant.id },
      data: {
        score,
        timeTaken,
        completedAt: new Date(),
        status: 'completed',
      },
    });

    // Fetch updated participants to check if all submitted
    const updatedParticipants = await prisma.challengeParticipant.findMany({
      where: { challengeId: challenge.id },
    });

    const allSubmitted = updatedParticipants.every((p) => p.completedAt);

    // Determine winner if all submitted
    let winnerId = null;
    let status = challenge.status;

    if (allSubmitted) {
      const sortedResults = [...updatedParticipants].sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return a.timeTaken - b.timeTaken; // Lower time wins if tie
      });

      winnerId = sortedResults[0].userId;
      status = 'completed';

      // Update ratings
      await this._updateRatings(challenge, updatedParticipants);

      // Create notifications for all participants
      await Promise.all(
        updatedParticipants.map((p) =>
          prisma.notification.create({
            data: {
              userId: p.userId,
              message:
                p.userId === winnerId
                  ? 'Congratulations! You won the challenge!'
                  : 'Challenge completed. Check the results!',
              type: 'challenge_completed',
              data: { challengeId: challenge.id, winnerId },
            },
          })
        )
      );
    }

    const updated = await prisma.challenge.update({
      where: { id: parseInt(id) },
      data: {
        status,
        winnerId,
        ...(status === 'completed' && { completedAt: new Date() }),
      },
    });

    return updated;
  }

  /**
   * Get user's challenges (sent, received, active, completed)
   */
  async getUserChallenges(userId, options = {}) {
    const { status, type, page = 1, limit = 20 } = options;

    const where = {
      OR: [
        { challengerId: userId },
        {
          participants: {
            some: {
              userId: userId,
              NOT: { userId: { equals: prisma.challenge.challengerId } }, // This isn't quite right in where
            },
          },
        },
      ],
      ...(status && { status }),
      ...(type && { type }),
    };

    // Correcting the where clause for "received"
    const finalWhere = {
      ...(status && { status }),
      ...(type && { type }),
      OR: [
        { challengerId: userId },
        {
          participants: {
            some: {
              userId: userId,
            },
          },
        },
      ],
    };

    const [challenges, total] = await Promise.all([
      prisma.challenge.findMany({
        where: finalWhere,
        include: {
          challenger: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
            },
          },
          participants: {
            include: {
              user: {
                select: {
                  id: true,
                  fullName: true,
                  avatarUrl: true,
                },
              },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.challenge.count({ where: finalWhere }),
    ]);

    return {
      challenges: challenges.map((c) => ({
        ...c,
        isSent: c.challengerId === userId,
        isReceived: c.challengerId !== userId && c.participants.some((p) => p.userId === userId),
      })),
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get challenge statistics for user
   */
  async getUserChallengeStats(userId) {
    const [sent, received, won, lost, active] = await Promise.all([
      prisma.challenge.count({
        where: { challengerId: userId },
      }),
      prisma.challenge.count({
        where: {
          challengerId: { not: userId },
          participants: { some: { userId } },
        },
      }),
      prisma.challenge.count({
        where: {
          winnerId: userId,
          status: 'completed',
        },
      }),
      prisma.challenge.count({
        where: {
          status: 'completed',
          winnerId: { not: userId, not: null },
          OR: [{ challengerId: userId }, { participants: { some: { userId } } }],
        },
      }),
      prisma.challenge.count({
        where: {
          status: 'active',
          OR: [{ challengerId: userId }, { participants: { some: { userId } } }],
        },
      }),
    ]);

    const total = sent + received;
    const completed = won + lost;
    const winRate = completed > 0 ? ((won / completed) * 100).toFixed(1) : 0;

    return {
      sent,
      received,
      won,
      lost,
      active,
      total,
      completed,
      winRate: parseFloat(winRate),
    };
  }

  /**
   * Update ratings based on challenge results (ELO-like system)
   */
  async _updateRatings(challenge, participants) {
    const K = 32; // K-factor for rating changes
    console.log(`DEBUG: Updating ratings for challenge ${challenge.id}`);

    for (const participant of participants) {
      if (participant.score === null) continue;

      const user = await prisma.user.findUnique({
        where: { id: participant.userId },
        select: { rating: true, xp: true },
      });

      if (!user) continue;

      // Calculate expected score vs each opponent
      let expectedScore = 0;
      let actualScore = 0;

      const opponents = participants.filter((p) => p.userId !== participant.userId);

      for (const opp of opponents) {
        if (opp.score === null) continue;

        const opponent = await prisma.user.findUnique({
          where: { id: opp.userId },
          select: { rating: true },
        });

        if (!opponent) continue;

        const expected = 1 / (1 + Math.pow(10, (opponent.rating - user.rating) / 400));
        expectedScore += expected;

        if (participant.score > opp.score) {
          actualScore += 1;
        } else if (participant.score === opp.score) {
          actualScore += 0.5;
        }
      }

      // Update rating
      const ratingChange = Math.round(K * (actualScore - expectedScore));
      console.log(`DEBUG: User ${participant.userId} rating change: ${ratingChange}`);

      await prisma.user.update({
        where: { id: participant.userId },
        data: {
          rating: { increment: ratingChange },
          xp: { increment: (participant.score || 0) * 10 },
        },
      });

      // Update leaderboard (overall)
      // Check if entry exists first to be safe with nullable unique fields
      try {
        const entry = await prisma.leaderboardEntry.findFirst({
          where: {
            userId: participant.userId,
            topicId: null,
            period: 'overall',
          },
        });

        if (entry) {
          await prisma.leaderboardEntry.update({
            where: { id: entry.id },
            data: {
              totalChallenges: { increment: 1 },
              wins: { increment: participant.userId === challenge.winnerId ? 1 : 0 },
              rating: { increment: ratingChange },
            },
          });
        } else {
          await prisma.leaderboardEntry.create({
            data: {
              userId: participant.userId,
              topicId: null,
              period: 'overall',
              totalChallenges: 1,
              wins: participant.userId === challenge.winnerId ? 1 : 0,
              rating: user.rating + ratingChange,
            },
          });
        }
      } catch (e) {
        console.error(`DEBUG: Leaderboard update failed for user ${participant.userId}:`, e.message);
        // Don't fail the whole request
      }
    }
  }
}

module.exports = new ChallengeService();
