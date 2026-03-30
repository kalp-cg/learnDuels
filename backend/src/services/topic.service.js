const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Topic Service - Handles hierarchical topic management
 * PRD Requirement: Topics with parent/child relationships
 */

class TopicService {
  /**
   * Create a new topic
   */
  async createTopic(data) {
    const { name, parentId, description } = data;

    // Validate parent exists if provided
    if (parentId) {
      const parent = await prisma.topic.findUnique({ where: { id: parentId } });
      if (!parent) {
        throw new Error('Parent topic not found');
      }
    }

    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '');

    const topic = await prisma.topic.create({
      data: { 
        name, 
        slug,
        description,
        parentId 
      },
    });

    return topic;
  }

  /**
   * Get all topics (flat list or hierarchical tree)
   */
  async getAllTopics(options = {}) {
    const { asTree = false } = options;

    const topics = await prisma.topic.findMany({
      include: {
        parent: true,
        children: true,
      },
      orderBy: { name: 'asc' },
    });

    if (asTree) {
      return this._buildTree(topics);
    }

    return topics;
  }

  /**
   * Get topic by ID with children
   */
  async getTopicById(id) {
    const topic = await prisma.topic.findUnique({
      where: { id: parseInt(id) },
      include: {
        parent: true,
        children: true,
        _count: {
          select: {
            questions: true,
          },
        },
      },
    });

    if (!topic) {
      throw new Error('Topic not found');
    }

    return topic;
  }

  /**
   * Update topic
   */
  async updateTopic(id, data) {
    const { name, parentId } = data;

    // Prevent circular reference
    if (parentId === parseInt(id)) {
      throw new Error('Topic cannot be its own parent');
    }

    // Check if new parent exists
    if (parentId) {
      const parent = await prisma.topic.findUnique({ where: { id: parentId } });
      if (!parent) {
        throw new Error('Parent topic not found');
      }
    }

    const topic = await prisma.topic.update({
      where: { id: parseInt(id) },
      data: { name, parentId },
      include: {
        parent: true,
        children: true,
      },
    });

    return topic;
  }

  /**
   * Delete topic (only if no questions attached)
   */
  async deleteTopic(id) {
    // Check if topic has questions
    const topic = await prisma.topic.findUnique({
      where: { id: parseInt(id) },
      include: {
        _count: {
          select: { questions: true },
        },
      },
    });

    if (!topic) {
      throw new Error('Topic not found');
    }

    if (topic._count.questions > 0) {
      throw new Error('Cannot delete topic with existing questions');
    }

    // Move children to parent level
    await prisma.topic.updateMany({
      where: { parentId: parseInt(id) },
      data: { parentId: topic.parentId },
    });

    await prisma.topic.delete({
      where: { id: parseInt(id) },
    });

    return { message: 'Topic deleted successfully' };
  }

  /**
   * Get topic hierarchy/breadcrumb
   */
  async getTopicPath(id) {
    const path = [];
    let currentId = parseInt(id);

    while (currentId) {
      const topic = await prisma.topic.findUnique({
        where: { id: currentId },
        select: { id: true, name: true, parentId: true },
      });

      if (!topic) break;

      path.unshift(topic);
      currentId = topic.parentId;
    }

    return path;
  }

  /**
   * Get all subtopics (recursive)
   */
  async getSubtopics(id) {
    const topic = await prisma.topic.findUnique({
      where: { id: parseInt(id) },
      include: {
        children: {
          include: {
            children: {
              include: {
                children: true, // 3 levels deep
              },
            },
          },
        },
      },
    });

    if (!topic) {
      throw new Error('Topic not found');
    }

    return topic.children;
  }

  /**
   * Search topics by name
   */
  async searchTopics(query) {
    const topics = await prisma.topic.findMany({
      where: {
        name: {
          contains: query,
          mode: 'insensitive',
        },
      },
      include: {
        parent: true,
        _count: {
          select: { questions: true },
        },
      },
      take: 20,
    });

    return topics;
  }

  /**
   * Get popular topics (by question count)
   */
  async getPopularTopics(limit = 10) {
    const topics = await prisma.topic.findMany({
      include: {
        _count: {
          select: { questions: true },
        },
      },
      orderBy: {
        questions: {
          _count: 'desc',
        },
      },
      take: limit,
    });

    return topics;
  }

  /**
   * Build hierarchical tree from flat list
   */
  _buildTree(topics, parentId = null) {
    const tree = [];

    topics
      .filter((topic) => topic.parentId === parentId)
      .forEach((topic) => {
        const node = {
          ...topic,
          children: this._buildTree(topics, topic.id),
        };
        tree.push(node);
      });

    return tree;
  }
}

module.exports = new TopicService();
