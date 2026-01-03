/**
 * Question Service
 * Handles question CRUD and management
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');
const { getCache, setCache, deleteCache, deleteCachePattern } = require('../config/redis');

/**
 * Create a new question
 */
async function createQuestion(questionData, authorId) {
  try {
    const {
      topicId, // Can be single ID or array of IDs
      topicIds: inputTopicIds, // Alternative field name
      difficulty, // String: 'easy', 'medium', 'hard'
      content,
      options, // JSON array: [{id: 'A', text: '...'}, ...]
      correctAnswer, // 'A', 'B', etc.
      explanation,
      type = 'mcq',
      status = 'draft'
    } = questionData;

    // Handle topic association
    // Prefer topicIds if provided, otherwise use topicId
    const rawTopicIds = inputTopicIds || topicId;
    const topicIds = Array.isArray(rawTopicIds) ? rawTopicIds : [rawTopicIds];

    // Filter out any undefined/null values
    const validTopicIds = topicIds.filter(id => id != null);

    const question = await prisma.question.create({
      data: {
        content,
        options,
        correctAnswer,
        explanation,
        difficulty,
        type,
        status,
        authorId: parseInt(authorId),
        topics: {
          create: validTopicIds.map(id => ({
            topic: { connect: { id: parseInt(id) } }
          }))
        }
      },
      include: {
        topics: {
          include: {
            topic: true
          }
        },
        author: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
    });

    // Invalidate questions cache
    await deleteCachePattern('questions:*');

    return question;
  } catch (error) {
    console.error('Create question error:', error);
    throw createError.internal('Failed to create question');
  }
}

/**
 * Get questions with filters
 */
async function getQuestions(filters = {}, options = {}) {
  const { topicId, difficulty, authorId } = filters;
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  // Try to get from cache first (skip cache if authorId filter is used for fresh data)
  const cacheKey = `questions:list:${topicId || 'all'}:${difficulty || 'all'}:${authorId || 'all'}:${page}:${limit}`;
  if (!authorId) {
    const cached = await getCache(cacheKey);
    if (cached) {
      return cached;
    }
  }

  try {
    const where = {
      deletedAt: null, // Exclude soft-deleted questions
    };

    if (topicId) {
      where.topics = {
        some: {
          topicId: parseInt(topicId)
        }
      };
    }

    if (difficulty) {
      where.difficulty = difficulty;
    }

    // Filter by author
    if (authorId) {
      where.authorId = parseInt(authorId);
    }

    const [questions, totalCount] = await Promise.all([
      prisma.question.findMany({
        where,
        include: {
          topics: {
            include: {
              topic: true
            }
          },
          author: {
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
      prisma.question.count({ where }),
    ]);

    const result = {
      questions,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };

    // Cache for 5 minutes
    await setCache(cacheKey, result, 300);

    return result;
  } catch (error) {
    console.error('Get questions error:', error);
    throw createError.internal('Failed to fetch questions');
  }
}

/**
 * Get question by ID
 */
async function getQuestionById(id, userId = null, includeAnswer = false) {
  const cacheKey = `questions:${id}:${includeAnswer}`;
  const cached = await getCache(cacheKey);
  if (cached) {
    return cached;
  }

  try {
    const question = await prisma.question.findFirst({
      where: { 
        id: parseInt(id),
        deletedAt: null // Exclude soft-deleted
      },
      include: {
        topics: {
          include: {
            topic: true
          }
        },
        author: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!question) {
      throw createError.notFound('Question not found');
    }

    // Hide correct answer if not requested or not authorized
    if (!includeAnswer) {
      delete question.correctAnswer;
      delete question.explanation;
    }

    await setCache(cacheKey, question, 300);

    return question;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to fetch question');
  }
}

/**
 * Update question
 */
async function updateQuestion(questionId, updateData, authorId) {
  try {
    // Verify ownership
    const existing = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!existing) {
      throw createError.notFound('Question not found');
    }

    if (existing.authorId !== parseInt(authorId)) {
      throw createError.forbidden('Not authorized to update this question');
    }

    const { topicId, ...rest } = updateData;
    const data = { ...rest };

    if (topicId) {
      // Handle topic update if needed (complex, skipping for now or simple replace)
    }

    const question = await prisma.question.update({
      where: { id: parseInt(questionId) },
      data,
      include: {
        topics: true,
      },
    });

    // Invalidate questions cache
    await deleteCachePattern('questions:*');
    await deleteCache(`question:${questionId}`);

    return question;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to update question');
  }
}

/**
 * Delete question (soft delete)
 */
async function deleteQuestion(questionId, authorId) {
  try {
    const existing = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!existing) {
      throw createError.notFound('Question not found');
    }

    if (existing.authorId !== parseInt(authorId)) {
      throw createError.forbidden('Not authorized to delete this question');
    }

    // Soft delete instead of hard delete
    await prisma.question.update({
      where: { id: parseInt(questionId) },
      data: { deletedAt: new Date() },
    });

    // Invalidate questions cache
    await deleteCachePattern('questions:*');
    await deleteCache(`question:${questionId}`);

    return { success: true };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to delete question');
  }
}

/**
 * Get random questions for a duel
 */
async function getRandomQuestions(filters = {}, count = 10, userIds = []) {
  try {
    const { categoryId, difficultyId } = filters;
    
    // 1. Get IDs of questions already answered by these users
    let excludedQuestionIds = [];
    if (userIds && userIds.length > 0) {
      const pastAnswers = await prisma.duelAnswer.findMany({
        where: { 
          playerId: { in: userIds.map(id => parseInt(id)) } 
        },
        select: { questionId: true },
        distinct: ['questionId']
      });
      excludedQuestionIds = pastAnswers.map(a => a.questionId);
    }

    const baseWhere = {
      deletedAt: null,
      status: 'published'
    };

    if (categoryId) {
      baseWhere.topics = { some: { topicId: parseInt(categoryId) } };
    }

    // Helper to resolve difficulty
    const resolveDifficulty = (diffId) => {
       const difficulties = ['easy', 'medium', 'hard'];
       if (typeof diffId === 'number') return difficulties[diffId - 1] || 'medium';
       if (typeof diffId === 'string') return diffId;
       return undefined;
    };
    const targetDifficulty = resolveDifficulty(difficultyId);

    let collectedQuestions = [];
    let needed = count;

    // Helper to fetch random batch
    const fetchBatch = async (criteria, limit) => {
        const count = await prisma.question.count({ where: criteria });
        if (count === 0) return [];
        const take = Math.min(limit * 2, count);
        const skip = Math.max(0, Math.floor(Math.random() * (count - take)));
        return prisma.question.findMany({
            where: criteria,
            take: take,
            skip: skip,
            include: {
                topics: true,
                author: { select: { id: true, fullName: true, username: true } }
            }
        });
    };

    // Step 1: Fresh & Target Difficulty
    if (needed > 0) {
        const where1 = { ...baseWhere, id: { notIn: excludedQuestionIds } };
        if (targetDifficulty) where1.difficulty = targetDifficulty;
        
        const batch1 = await fetchBatch(where1, needed);
        const selected1 = batch1.sort(() => 0.5 - Math.random()).slice(0, needed);
        collectedQuestions = [...collectedQuestions, ...selected1];
        needed -= selected1.length;
    }

    // Step 2: Fresh & Any Difficulty (only if we didn't get enough)
    if (needed > 0) {
        const currentIds = collectedQuestions.map(q => q.id);
        const where2 = { 
            ...baseWhere, 
            id: { notIn: [...excludedQuestionIds, ...currentIds] } 
        };
        
        const batch2 = await fetchBatch(where2, needed);
        const selected2 = batch2.sort(() => 0.5 - Math.random()).slice(0, needed);
        collectedQuestions = [...collectedQuestions, ...selected2];
        needed -= selected2.length;
    }

    // Step 3: Seen & Target Difficulty (Recycle seen questions if we ran out of fresh ones)
    if (needed > 0) {
        console.log(`Not enough fresh questions. Recycling seen questions for users ${userIds}`);
        const currentIds = collectedQuestions.map(q => q.id);
        const where3 = {
            ...baseWhere,
            id: { notIn: currentIds } // Only exclude what we just picked in this session
        };
        if (targetDifficulty) where3.difficulty = targetDifficulty;

        const batch3 = await fetchBatch(where3, needed);
        const selected3 = batch3.sort(() => 0.5 - Math.random()).slice(0, needed);
        collectedQuestions = [...collectedQuestions, ...selected3];
        needed -= selected3.length;
    }

    // Step 4: Seen & Any Difficulty (Last resort)
    if (needed > 0) {
        const currentIds = collectedQuestions.map(q => q.id);
        const where4 = {
            ...baseWhere,
            id: { notIn: currentIds }
        };
        
        const batch4 = await fetchBatch(where4, needed);
        const selected4 = batch4.sort(() => 0.5 - Math.random()).slice(0, needed);
        collectedQuestions = [...collectedQuestions, ...selected4];
        needed -= selected4.length;
    }

    return collectedQuestions;
  } catch (error) {
    console.error('Get random questions error:', error);
    throw createError.internal(`Failed to fetch random questions: ${error.message}`);
  }
}

/**
 * Search questions
 */
async function searchQuestions(searchQuery, filters = {}, options = {}) {
  const { categoryId, difficultyId } = filters;
  const { page = 1, limit = 20 } = options;
  const skip = (page - 1) * limit;

  try {
    const where = {};

    if (searchQuery) {
      where.content = {
        contains: searchQuery,
        mode: 'insensitive',
      };
    }

    if (categoryId) {
      where.topics = {
        some: {
          topicId: parseInt(categoryId)
        }
      };
    }

    if (difficultyId) where.difficulty = difficultyId;

    const [questions, totalCount] = await Promise.all([
      prisma.question.findMany({
        where,
        include: {
          topics: true,
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.question.count({ where }),
    ]);

    return {
      questions,
      pagination: {
        total: totalCount,
        page,
        limit,
        totalPages: Math.ceil(totalCount / limit),
      },
    };
  } catch (error) {
    throw createError.internal('Failed to search questions');
  }
}

module.exports = {
  createQuestion,
  getQuestions,
  getQuestionById,
  updateQuestion,
  deleteQuestion,
  getRandomQuestions,
  searchQuestions,
};
