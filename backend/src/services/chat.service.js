const { prisma } = require('../config/db');
const { createError } = require('../middlewares/error.middleware');

/**
 * Create or get existing direct conversation
 */
async function getOrCreateDirectConversation(userId1, userId2) {
  // Check if conversation exists
  // We need to find a conversation where BOTH users are participants
  // This query is a bit tricky in Prisma. 
  // We find conversations where user1 is a participant, then filter in JS or use advanced query
  
  // A more robust way:
  const conversations = await prisma.conversation.findMany({
    where: {
      type: 'direct',
      participants: {
        some: { userId: userId1 }
      }
    },
    include: {
      participants: true
    }
  });

  const existing = conversations.find(c => 
    c.participants.some(p => p.userId === userId2)
  );

  if (existing) {
    return await prisma.conversation.findUnique({
      where: { id: existing.id },
      include: {
        participants: {
          include: {
            user: {
              select: { id: true, username: true, avatarUrl: true, fullName: true }
            }
          }
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1
        }
      }
    });
  }

  // Create new
  return await prisma.conversation.create({
    data: {
      type: 'direct',
      participants: {
        create: [
          { userId: userId1 },
          { userId: userId2 }
        ]
      }
    },
    include: {
      participants: {
        include: {
          user: {
            select: { id: true, username: true, avatarUrl: true, fullName: true }
          }
        }
      }
    }
  });
}

/**
 * Send a message
 */
async function sendMessage(senderId, conversationId, content) {
  const conversation = await prisma.conversation.findUnique({
    where: { id: parseInt(conversationId) },
    include: { participants: true }
  });

  if (!conversation) throw createError(404, 'Conversation not found');

  const isParticipant = conversation.participants.some(p => p.userId === senderId);
  if (!isParticipant) throw createError(403, 'Not a participant');

  const message = await prisma.message.create({
    data: {
      conversationId: parseInt(conversationId),
      senderId,
      content
    },
    include: {
      sender: {
        select: { id: true, username: true, avatarUrl: true }
      }
    }
  });

  // Update conversation updated_at
  await prisma.conversation.update({
    where: { id: parseInt(conversationId) },
    data: { updatedAt: new Date() }
  });

  return message;
}

/**
 * Get user conversations
 */
async function getUserConversations(userId) {
  return await prisma.conversation.findMany({
    where: {
      participants: { some: { userId } }
    },
    include: {
      participants: {
        include: {
          user: {
            select: { id: true, username: true, avatarUrl: true, fullName: true }
          }
        }
      },
      messages: {
        orderBy: { createdAt: 'desc' },
        take: 1
      }
    },
    orderBy: { updatedAt: 'desc' }
  });
}

/**
 * Get messages for a conversation
 */
async function getConversationMessages(userId, conversationId, { page = 1, limit = 50 }) {
  const conversation = await prisma.conversation.findUnique({
    where: { id: parseInt(conversationId) },
    include: { participants: true }
  });

  if (!conversation) throw createError(404, 'Conversation not found');
  
  const isParticipant = conversation.participants.some(p => p.userId === userId);
  if (!isParticipant) throw createError(403, 'Not a participant');

  const skip = (page - 1) * limit;

  const messages = await prisma.message.findMany({
    where: { conversationId: parseInt(conversationId) },
    orderBy: { createdAt: 'desc' },
    skip,
    take: limit,
    include: {
      sender: {
        select: { id: true, username: true, avatarUrl: true }
      }
    }
  });

  return messages.reverse(); 
}

module.exports = {
  getOrCreateDirectConversation,
  sendMessage,
  getUserConversations,
  getConversationMessages
};
