/**
 * Category and Difficulty Service
 * Handles categories and difficulty levels
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');
const { getCache, setCache, deleteCache } = require('../config/redis');

/**
 * Get all categories
 */
async function getAllCategories() {
  // Try to get from cache first
  const cacheKey = 'categories:all';
  const cached = await getCache(cacheKey);
  if (cached) {
    return cached;
  }

  try {
    const categories = await prisma.category.findMany({
      include: {
        _count: {
          select: {
            questions: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });

    // Cache for 10 minutes (categories rarely change)
    await setCache(cacheKey, categories, 600);

    return categories;
  } catch (error) {
    throw createError.internal('Failed to fetch categories');
  }
}

/**
 * Create category
 */
async function createCategory(name) {
  try {
    const existing = await prisma.category.findUnique({
      where: { name },
    });

    if (existing) {
      throw createError.conflict('Category already exists');
    }

    const category = await prisma.category.create({
      data: { name },
    });

    // Invalidate categories cache
    await deleteCache('categories:all');

    return category;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to create category');
  }
}

/**
 * Get all difficulty levels
 */
async function getAllDifficulties() {
  // Try to get from cache first
  const cacheKey = 'difficulties:all';
  const cached = await getCache(cacheKey);
  if (cached) {
    return cached;
  }

  try {
    const difficulties = await prisma.difficulty.findMany({
      include: {
        _count: {
          select: {
            questions: true,
          },
        },
      },
      orderBy: { id: 'asc' },
    });

    // Cache for 10 minutes (difficulties rarely change)
    await setCache(cacheKey, difficulties, 600);

    return difficulties;
  } catch (error) {
    throw createError.internal('Failed to fetch difficulties');
  }
}

/**
 * Create difficulty level
 */
async function createDifficulty(level) {
  try {
    const existing = await prisma.difficulty.findUnique({
      where: { level },
    });

    if (existing) {
      throw createError.conflict('Difficulty level already exists');
    }

    const difficulty = await prisma.difficulty.create({
      data: { level },
    });

    // Invalidate difficulties cache
    await deleteCache('difficulties:all');

    return difficulty;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to create difficulty');
  }
}

module.exports = {
  getAllCategories,
  createCategory,
  getAllDifficulties,
  createDifficulty,
};
