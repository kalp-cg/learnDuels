const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const feedService = require('./feed.service');

/**
 * QuestionSet Service - Manages saved question collections/quizzes
 * PRD Requirement: Create saved sets with public/private visibility
 */

class QuestionSetService {
  /**
   * Create a new question set
   */
  async createQuestionSet(data, authorId) {
    const { name, questionIds, visibility = 'private' } = data;

    // Validate questions exist
    const questions = await prisma.question.findMany({
      where: {
        id: { in: questionIds },
        status: 'published', // Only published questions
      },
    });

    if (questions.length !== questionIds.length) {
      throw new Error('Some questions not found or not published');
    }

    const questionSet = await prisma.questionSet.create({
      data: {
        name,
        authorId,
        visibility,
        items: {
          create: questionIds.map((id, index) => ({
            questionId: id,
            orderIndex: index
          }))
        }
      },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
    });

    // Add to activity feed if public
    if (visibility === 'public') {
      try {
        await feedService.createActivity(authorId, 'QUIZ_CREATED', {
          questionSetId: questionSet.id,
          name: questionSet.name,
          questionCount: questionIds.length
        });
      } catch (error) {
        console.error('Failed to create feed activity for quiz creation:', error);
      }
    }

    return questionSet;
  }

  /**
   * Get question set by ID with questions
   */
  async getQuestionSetById(id, userId) {
    const questionSet = await prisma.questionSet.findUnique({
      where: { 
        id: parseInt(id),
        deletedAt: null // Exclude soft-deleted
      },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
            reputation: true,
          },
        },
      },
    });

    if (!questionSet) {
      throw new Error('Question set not found');
    }

    // Check visibility permissions
    if (questionSet.visibility === 'private' && questionSet.authorId !== userId) {
      throw new Error('Access denied');
    }

    // Fetch actual questions
    const questions = await prisma.question.findMany({
      where: {
        id: { in: questionSet.questionIds },
      },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
          },
        },
      },
    });

    return {
      ...questionSet,
      questions,
      questionCount: questions.length,
    };
  }

  /**
   * Get all question sets (public or user's own)
   */
  async getQuestionSets(options = {}) {
    const { userId, visibility, authorId, page = 1, limit = 20 } = options;

    const where = { deletedAt: null }; // Exclude soft-deleted records

    // Visibility filter
    if (visibility) {
      where.visibility = visibility;
    } else {
      // Show public sets or user's private sets
      where.OR = [
        { visibility: 'public' },
        { authorId: userId },
      ];
    }

    // Filter by author
    if (authorId) {
      where.authorId = parseInt(authorId);
    }

    const [questionSets, total] = await Promise.all([
      prisma.questionSet.findMany({
        where,
        include: {
          author: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.questionSet.count({ where }),
    ]);

    return {
      questionSets: questionSets.map((qs) => ({
        ...qs,
        questionCount: qs.questionIds.length,
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
   * Update question set
   */
  async updateQuestionSet(id, data, userId) {
    const questionSet = await prisma.questionSet.findUnique({
      where: { id: parseInt(id) },
    });

    if (!questionSet) {
      throw new Error('Question set not found');
    }

    // Only author can update
    if (questionSet.authorId !== userId) {
      throw new Error('Access denied');
    }

    const { name, questionIds, visibility } = data;

    // Validate questions if updating
    if (questionIds) {
      const questions = await prisma.question.findMany({
        where: {
          id: { in: questionIds },
          status: 'published',
        },
      });

      if (questions.length !== questionIds.length) {
        throw new Error('Some questions not found or not published');
      }
    }

    const updated = await prisma.questionSet.update({
      where: { id: parseInt(id) },
      data: {
        ...(name && { name }),
        ...(questionIds && { questionIds }),
        ...(visibility && { visibility }),
      },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return updated;
  }

  /**
   * Delete question set (soft delete)
   */
  async deleteQuestionSet(id, userId) {
    const questionSet = await prisma.questionSet.findUnique({
      where: { id: parseInt(id) },
    });

    if (!questionSet) {
      throw new Error('Question set not found');
    }

    // Only author can delete
    if (questionSet.authorId !== userId) {
      throw new Error('Access denied');
    }

    // Soft delete instead of hard delete
    await prisma.questionSet.update({
      where: { id: parseInt(id) },
      data: { deletedAt: new Date() },
    });

    return { message: 'Question set deleted successfully' };
  }

  /**
   * Add question to set
   */
  async addQuestion(setId, questionId, userId) {
    const questionSet = await prisma.questionSet.findUnique({
      where: { id: parseInt(setId) },
    });

    if (!questionSet) {
      throw new Error('Question set not found');
    }

    if (questionSet.authorId !== userId) {
      throw new Error('Access denied');
    }

    // Check question exists and is published
    const question = await prisma.question.findUnique({
      where: { id: parseInt(questionId) },
    });

    if (!question || question.status !== 'published') {
      throw new Error('Question not found or not published');
    }

    // Add if not already in set
    if (!questionSet.questionIds.includes(questionId)) {
      const updated = await prisma.questionSet.update({
        where: { id: parseInt(setId) },
        data: {
          questionIds: [...questionSet.questionIds, questionId],
        },
      });

      return updated;
    }

    return questionSet;
  }

  /**
   * Remove question from set
   */
  async removeQuestion(setId, questionId, userId) {
    const questionSet = await prisma.questionSet.findUnique({
      where: { id: parseInt(setId) },
    });

    if (!questionSet) {
      throw new Error('Question set not found');
    }

    if (questionSet.authorId !== userId) {
      throw new Error('Access denied');
    }

    const updated = await prisma.questionSet.update({
      where: { id: parseInt(setId) },
      data: {
        questionIds: questionSet.questionIds.filter((id) => id !== questionId),
      },
    });

    return updated;
  }

  /**
   * Clone/duplicate a question set
   */
  async cloneQuestionSet(id, userId, newName) {
    const original = await prisma.questionSet.findUnique({
      where: { id: parseInt(id) },
    });

    if (!original) {
      throw new Error('Question set not found');
    }

    // Can only clone public sets or own sets
    if (original.visibility === 'private' && original.authorId !== userId) {
      throw new Error('Access denied');
    }

    const cloned = await prisma.questionSet.create({
      data: {
        name: newName || `${original.name} (Copy)`,
        authorId: userId,
        questionIds: original.questionIds,
        visibility: 'private', // Cloned sets are private by default
      },
    });

    return cloned;
  }

  /**
   * Get popular/trending question sets
   */
  async getPopularQuestionSets(limit = 10) {
    // Based on usage in attempts (will implement after Attempt model)
    const questionSets = await prisma.questionSet.findMany({
      where: { visibility: 'public' },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
            reputation: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return questionSets.map((qs) => ({
      ...qs,
      questionCount: qs.questionIds.length,
    }));
  }

  /**
   * Auto-generate quiz from topic and difficulty
   * PRD Requirement: Auto-generate quiz from topic + difficulty + numQuestions
   */
  async generateQuiz(params, userId) {
    const { topicId, difficulty, numQuestions = 10, name } = params;

    // Validate parameters
    if (!topicId) {
      throw new Error('Topic ID is required');
    }

    // Build query for questions
    const where = {
      status: 'published',
    };

    // Filter by difficulty if provided
    if (difficulty) {
      where.difficulty = difficulty;
    }

    // Filter by topic
    where.topics = {
      some: {
        topicId: parseInt(topicId),
      },
    };

    // Get available questions count
    const availableCount = await prisma.question.count({ where });

    if (availableCount === 0) {
      throw new Error('No questions available for the selected criteria');
    }

    if (availableCount < numQuestions) {
      throw new Error(
        `Only ${availableCount} questions available. Requested ${numQuestions}.`
      );
    }

    // Fetch all matching questions
    const allQuestions = await prisma.question.findMany({
      where,
      select: { id: true },
    });

    // Randomly select questions
    const shuffled = allQuestions.sort(() => 0.5 - Math.random());
    const selectedQuestions = shuffled.slice(0, numQuestions);
    const questionIds = selectedQuestions.map((q) => q.id);

    // Get topic name for quiz name
    const topic = await prisma.topic.findUnique({
      where: { id: parseInt(topicId) },
      select: { name: true },
    });

    // Create the question set
    const quizName =
      name ||
      `${topic?.name || 'Quiz'} - ${difficulty || 'Mixed'} (${numQuestions} questions)`;

    const questionSet = await this.createQuestionSet(
      {
        name: quizName,
        questionIds,
        visibility: 'private', // Generated quizzes are private by default
      },
      userId
    );

    return questionSet;
  }
}

module.exports = new QuestionSetService();
