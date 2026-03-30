/**
 * Subscription Service
 * Handles subscription plans and user subscriptions
 */

const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');

/**
 * Get all subscription plans
 */
async function getAllPlans() {
  try {
    const plans = await prisma.subscriptionPlan.findMany({
      orderBy: { price: 'asc' },
    });

    return plans;
  } catch (error) {
    throw createError.internal('Failed to fetch subscription plans');
  }
}

/**
 * Get plan by ID
 */
async function getPlanById(planId) {
  try {
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: parseInt(planId) },
    });

    if (!plan) {
      throw createError.notFound('Plan not found');
    }

    return plan;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to fetch plan');
  }
}

/**
 * Subscribe user to a plan
 */
async function subscribe(userId, planId) {
  try {
    const plan = await getPlanById(planId);

    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + plan.duration);

    const subscription = await prisma.userSubscription.create({
      data: {
        userId: parseInt(userId),
        planId: parseInt(planId),
        startDate,
        endDate,
      },
      include: {
        plan: true,
      },
    });

    return subscription;
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to create subscription');
  }
}

/**
 * Get user's active subscription
 */
async function getUserSubscription(userId) {
  try {
    const subscription = await prisma.userSubscription.findFirst({
      where: {
        userId: parseInt(userId),
        endDate: {
          gte: new Date(),
        },
      },
      include: {
        plan: true,
      },
      orderBy: { endDate: 'desc' },
    });

    return subscription;
  } catch (error) {
    throw createError.internal('Failed to fetch subscription');
  }
}

/**
 * Check if user has active subscription
 */
async function hasActiveSubscription(userId) {
  try {
    const subscription = await getUserSubscription(userId);
    return !!subscription;
  } catch (error) {
    return false;
  }
}

/**
 * Cancel subscription
 */
async function cancelSubscription(userId) {
  try {
    const subscription = await getUserSubscription(userId);

    if (!subscription) {
      throw createError.notFound('No active subscription found');
    }

    // Set end date to now
    await prisma.userSubscription.update({
      where: { id: subscription.id },
      data: { endDate: new Date() },
    });

    return { success: true };
  } catch (error) {
    if (error.isOperational) throw error;
    throw createError.internal('Failed to cancel subscription');
  }
}

module.exports = {
  getAllPlans,
  getPlanById,
  subscribe,
  getUserSubscription,
  hasActiveSubscription,
  cancelSubscription,
};
