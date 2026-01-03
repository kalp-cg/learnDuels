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
async function getRandomQuestions(filters = {}, count = 10) {
  try {
    const { categoryId, difficultyId } = filters;
    const where = {
      deletedAt: null,
      status: 'published'
    };

    if (categoryId) {
      where.topics = {
        some: {
          topicId: parseInt(categoryId)
        }
      };
    }

    if (difficultyId) {
      // Map ID to string if necessary, or use default
      const difficulties = ['easy', 'medium', 'hard'];
      if (typeof difficultyId === 'number') {
        where.difficulty = difficulties[difficultyId - 1] || 'medium';
      } else if (typeof difficultyId === 'string') {
        where.difficulty = difficultyId;
      }
    }

    // Get random questions using raw query for better performance on large datasets
    // But for now, using findMany with random skip/take or shuffle in app
    // Since Prisma doesn't support ORDER BY RANDOM() easily across DBs

    let totalCount = await prisma.question.count({ where });
    let questions = [];

    // 1. Try to get questions with specific difficulty
    if (totalCount > 0) {
      const take = Math.min(count * 2, totalCount);
      const skip = Math.max(0, Math.floor(Math.random() * (totalCount - take)));

      questions = await prisma.question.findMany({
        where,
        take: take,
        skip: skip,
        include: {
          topics: true,
          author: {
            select: {
              id: true,
              fullName: true,
              username: true
            }
          }
        }
      });
    }

    // 2. If not enough questions, fetch from ANY difficulty to fill the quota
    if (questions.length < count) {
      console.log(`Not enough questions found for difficulty ${where.difficulty || 'any'} (Found: ${questions.length}, Needed: ${count}). Fetching more...`);
      
      // Exclude already fetched questions
      const existingIds = questions.map(q => q.id);
      
      // Use base criteria (category only) without difficulty filter
      const fallbackWhere = {
        deletedAt: null,
        status: 'published',
        id: { notIn: existingIds }
      };

      if (categoryId) {
        fallbackWhere.topics = {
          some: {
            topicId: parseInt(categoryId)
          }
        };
      }

      const remainingCount = count - questions.length;
      const fallbackTotal = await prisma.question.count({ where: fallbackWhere });
      
      if (fallbackTotal > 0) {
           // Fetch more than needed to allow for some randomness
           const take = Math.min(remainingCount * 2, fallbackTotal);
           const skip = Math.max(0, Math.floor(Math.random() * (fallbackTotal - take)));

           const moreQuestions = await prisma.question.findMany({
              where: fallbackWhere,
              take: take,
              skip: skip,
              include: {
                  topics: true,
                  author: {
                      select: {
                          id: true,
                          fullName: true,
                          username: true
                      }
                  }
              }
          });
          questions = [...questions, ...moreQuestions];
      }
    }

    // Shuffle in memory
    const shuffled = questions.sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
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
